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
        case regularExpression(NSRegularExpression)
    }

    private let storage: Storage

    public var regex: String {
        switch storage {
            case .expression(let tokens): return Self.regex(for: tokens)
            case .regularExpression(let regularExpression): return regularExpression.pattern
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
            storage = .regularExpression(Self.compile(str, in: str, reason: "starts with ^ or ends with $",
                                                        fix: "Remove the anchors, or write a valid regular expression."))
        } else if str.count >= 2, str.first == "/", str.last == "/" {
            let pattern = String(str.dropFirst().dropLast())
            storage = .regularExpression(Self.compile(pattern, in: str, reason: "is written between slashes",
                                                        fix: "Remove the slashes, or write a valid regular expression."))
        } else {
            storage = .expression(Lexer(str).lex())
        }
    }

    private static func compile(_ pattern: String, in expression: String, reason: String, fix: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern)
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
            case .regularExpression(let regularExpression): return match(in: str, regularExpression: regularExpression)
        }
    }

    /// Every capture group becomes an anonymous parameter, so its text is available through `\.anonymous`.
    private func match(in str: String, regularExpression: NSRegularExpression) -> Match? {
        guard let result = regularExpression.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)) else { return nil }
        let match = Match()
        for group in 1..<max(result.numberOfRanges, 1) {
            guard let range = Range(result.range(at: group), in: str) else { continue }
            match.append(.parameter(Position(line: 0, column: UInt(group)), AnonymousParameter.name),
                         matchedText: String(str[range]))
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
