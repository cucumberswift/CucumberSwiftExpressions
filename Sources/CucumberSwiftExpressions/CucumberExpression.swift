//
//  CucumberExpression.swift
//  CucumberSwiftExpressions
//
//  Created by Tyler Thompson on 8/20/22.
//  Copyright © 2022 Tyler Thompson. All rights reserved.
//

import Foundation

public struct CucumberExpression: ExpressibleByStringLiteral {
    private enum Storage {
        case expression([Lexer.Token])
        case regularExpression(NSRegularExpression, topLevelGroups: [Int])
    }

    private let storage: Storage

    public var regex: String {
        switch storage {
            case .expression(let tokens): return Self.regex(for: tokens)
            case .regularExpression(let regularExpression, _): return regularExpression.pattern
        }
    }

    private static func regex(for tokens: [Lexer.Token]) -> String {
        tokens
            .lazy
            .map {
                switch $0 {
                    case .whitespace(_, let val): return val
                    case .parameter(_, let parameterName):
                        if let lookup = Self.parameterLookup[parameterName] {
                            return "(\(lookup.regexMatch))"
                        }
                        return ""
                    case .alternate(_, let alternates):
                        return "(?:\(alternates.lazy.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")))"
                    case .optional(_, let optionalText):
                        let escapedText = NSRegularExpression.escapedPattern(for: optionalText)
                        return "(?:\(escapedText))?"
                    case .literal(_, let val):
                        return NSRegularExpression.escapedPattern(for: val)
                }
            }
            .joined()
            .reduce(into: "^") { $0 += String($1) } + "$"
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// Creates an expression from a string, using the same heuristics as the reference implementation:
    /// a string that starts with `^` or ends with `$` is a regular expression, a string written as
    /// `/pattern/` is a regular expression (the slashes are not part of the pattern), and anything else
    /// is a Cucumber expression.
    ///
    /// A string that is treated as a regular expression but is not a valid one is a mistake in the
    /// step definition, so this traps rather than producing an expression that matches nothing.
    public init(_ str: String) {
        if str.first == "^" || str.last == "$" {
            storage = Self.compile(str, in: str, reason: "starts with ^ or ends with $",
                                   fix: "Remove the anchors, or write a valid regular expression.")
        } else if str.count >= 2, str.first == "/", str.last == "/" {
            let pattern = String(str.dropFirst().dropLast())
            storage = Self.compile(pattern, in: str, reason: "is written between slashes",
                                   fix: "Remove the slashes, or write a valid regular expression.")
        } else {
            storage = .expression(Lexer(str).lex())
        }
    }

    private static func compile(_ pattern: String, in expression: String, reason: String, fix: String) -> Storage {
        do {
            let regularExpression = try NSRegularExpression(pattern: pattern)
            return .regularExpression(regularExpression, topLevelGroups: topLevelGroups(of: regularExpression))
        } catch {
            preconditionFailure("""
                CucumberExpression: "\(expression)" \(reason), so it is treated as a regular expression, \
                but it is not valid as one. \(fix)
                """)
        }
    }

    public func match(in str: String) -> Match? {
        switch storage {
            case .expression(let tokens): return match(in: str, tokens: tokens)
            case .regularExpression(let regularExpression, let groups): return match(in: str, regularExpression: regularExpression, groups: groups)
        }
    }

    /// Every top-level capture group becomes an anonymous parameter, so its text is available through
    /// `\.anonymous`. As upstream, groups nested inside another group are not arguments, and a group
    /// that did not take part in the match keeps its position with empty text.
    private func match(in str: String, regularExpression: NSRegularExpression, groups: [Int]) -> Match? {
        guard let result = regularExpression.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)) else { return nil }
        let match = Match()
        for group in groups where group < result.numberOfRanges {
            let text = Range(result.range(at: group), in: str).map { String(str[$0]) } ?? ""
            match.append(.parameter(Position(line: 0, column: UInt(group)), AnonymousParameter.name),
                         matchedText: text)
        }
        return match
    }

    private func match(in str: String, tokens: [Lexer.Token]) -> Match? {
        let match = Match()
        let parameters = tokens.filter { $0.isParameter }
        let regexMatches = matches(in: str, regex: Self.regex(for: tokens))
        
        guard !regexMatches.isEmpty else { return nil }
        
        let matches = regexMatches
            .dropFirst() // first match is the whole string
                .reduce(into: [[(range: Range<String.Index>, match: String)]]()) { allMatches, tup in
                    let (range, strMatch) = tup
                    if let lastRange = allMatches.last?.first?.range,
                       lastRange.contains(range.lowerBound),
                       lastRange.contains(range.upperBound) {
                        allMatches[allMatches.count - 1].append((range, strMatch))
                    } else {
                        allMatches.append([(range, strMatch)])
                    }
                }

        guard matches.count == parameters.count else { return nil }

        for (offset, element) in parameters.enumerated() {
            guard case .parameter(_, let parameterName) = element,
                  let lookup = Self.parameterLookup[parameterName] else { return nil }
            let strMatches = matches[offset].map(\.match)
            match.append(element, matchedText: lookup.selectMatch(strMatches))
        }

        return match
    }

    private func matches(in str: String, regex: String) -> [(Range<String.Index>, String)] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: str,
                                        range: NSRange(str.startIndex..., in: str))
            guard let firstResult = results.first else { return [] }
            var matches = [(Range<String.Index>, String)]()
            for i in 0..<firstResult.numberOfRanges {
                if let range = Range(firstResult.range(at: i), in: str) {
                    matches.append((range, String(str[range])))
                }
            }
            return matches
        } catch {
            return []
        }
    }

    /// The numbers of the capture groups that are not nested inside another capture group.
    private static func topLevelGroups(of regularExpression: NSRegularExpression) -> [Int] {
        var scanner = GroupScanner(Array(regularExpression.pattern))
        scanner.scan()
        // If this scan ever disagrees with ICU, expose every group rather than guess.
        let total = regularExpression.numberOfCaptureGroups
        return scanner.count == total ? scanner.topLevel : Array(stride(from: 1, through: total, by: 1))
    }

    /// Walks an ICU pattern and records which capture groups are not nested inside another one.
    private struct GroupScanner {
        let characters: [Character]
        var index = 0
        var count = 0
        var topLevel = [Int]()
        private var open = [Bool]() // one entry per open parenthesis: is it a capture group?
        private var classDepth = 0
        private var extended = false // `(?x)`: `#` starts a comment that runs to the end of the line

        init(_ characters: [Character]) {
            self.characters = characters
        }

        mutating func scan() {
            while index < characters.count {
                let character = characters[index]
                if character == "\\" {
                    skipEscape()
                } else if classDepth > 0 {
                    if character == "[" { classDepth += 1 } else if character == "]" { classDepth -= 1 }
                    index += 1
                } else if character == "#" && extended {
                    skip(until: "\n")
                } else {
                    scanOutsideClass(character)
                    index += 1
                }
            }
        }

        private func peek(_ offset: Int) -> Character? {
            index + offset < characters.count ? characters[index + offset] : nil
        }

        private mutating func skipEscape() {
            guard peek(1) == "Q" else { index += 2; return }
            index += 2
            while index < characters.count, !(characters[index] == "\\" && peek(1) == "E") { index += 1 }
            index += 2
        }

        private mutating func skip(until terminator: Character) {
            while index < characters.count, characters[index] != terminator { index += 1 }
        }

        private mutating func scanOutsideClass(_ character: Character) {
            switch character {
                case "[": classDepth = 1
                case ")": _ = open.popLast()
                case "(": openGroup()
                default: break
            }
        }

        private mutating func openGroup() {
            var isCapture = true
            if peek(1) == "?" {
                if peek(2) == "#" { // `(?# comment )`
                    skip(until: ")")
                    return
                }
                isCapture = peek(2) == "<" && peek(3) != "=" && peek(3) != "!"
                enableExtendedModeIfFlagged()
            }
            if isCapture {
                count += 1
                if !open.contains(true) { topLevel.append(count) }
            }
            open.append(isCapture)
        }

        /// Recognises `(?x)`, `(?ix)`, `(?x-i:` and similar flag groups.
        private mutating func enableExtendedModeIfFlagged() {
            var offset = 2
            var isOn = true
            while let flag = peek(offset), flag.isLetter || flag == "-" {
                if flag == "-" { isOn = false }
                if flag == "x" { extended = isOn }
                offset += 1
            }
        }
    }
}

extension CucumberExpression {
    static let parameters: [AnyParameter] = {
        [
            StringParameter().eraseToAnyParameter(),
            IntParameter().eraseToAnyParameter(),
            WordParameter().eraseToAnyParameter(),
            FloatParameter().eraseToAnyParameter(),
            DoubleParameter().eraseToAnyParameter(),
            AnonymousParameter().eraseToAnyParameter()
        ]
    }()

    static var parameterLookup: [String: AnyParameter] = {
        parameters
            .reduce(into: [:]) { $0[$1.name] = $1 }
            .merging((Self.self as? CustomParameters.Type)?.parameterLookup ?? [:]) { $1 }
    }()
}
