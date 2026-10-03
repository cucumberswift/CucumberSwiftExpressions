//
//  SyntaxParser.swift
//  CucumberSwiftExpressions
//

import Foundation

/// Reads a Cucumber expression strictly, as the specification and cucumber-jvm do, to find its
/// parameters and its syntax errors. It follows cucumber-jvm's `CucumberExpressionTokenizer`,
/// `CucumberExpressionParser` and the checks in `CucumberExpression`, so it finds the same first error.
///
/// Matching does not use it: ``Lexer`` stays lenient, so existing expressions match as they always have.
/// For an expression this parser accepts, the two find the same parameters.
///
/// Positions are offsets into the expression, counted in characters.
struct SyntaxParser {
    private typealias Result = (consumed: Int, nodes: [Node])

    private enum TokenKind: Equatable {
        case startOfLine, endOfLine, whitespace, beginOptional, endOptional, beginParameter, endParameter,
             alternation, text
    }

    private struct Token {
        let kind: TokenKind
        /// The token's text, with escapes removed.
        var text: String
        let start: Int
        var end: Int
    }

    private struct Node {
        enum Kind: Equatable {
            case text, optional, alternation, alternative, parameter, expression
        }

        let kind: Kind
        let start: Int
        let end: Int
        var children = [Node]()
        var token = ""

        /// A text node's text, or the text of the nodes inside it, such as a parameter's name.
        var text: String {
            kind == .text ? token : children.map(\.text).joined()
        }
    }

    private enum Rule {
        case text, name, parameter, optional, alternativeSeparator, alternation, expression
    }

    private static let optionRules: [Rule] = [.optional, .parameter, .text]
    private static let alternativeRules: [Rule] = [.alternativeSeparator, .optional, .parameter, .text]
    private static let expressionRules: [Rule] = [.alternation, .optional, .parameter, .text]

    private let expression: String
    private let characters: [Character]

    init(_ expression: String) {
        self.expression = expression
        characters = Array(expression)
    }

    /// The expression's parameters, in order.
    func arguments() throws -> [CucumberExpression.Argument] {
        let tokens = try tokenize()
        let ast = try parse(.expression, tokens, at: 0).nodes[0]
        var parameters = [Node]()
        try check(ast, collecting: &parameters)
        let indices = Array(expression.indices) + [expression.endIndex]
        return parameters.map {
            CucumberExpression.Argument(parameterName: $0.text, range: indices[$0.start]..<indices[$0.end])
        }
    }

    private func error(_ problem: CucumberExpression.SyntaxError.Problem, _ start: Int, _ end: Int) -> CucumberExpression.SyntaxError {
        CucumberExpression.SyntaxError(problem, at: start..<end, in: expression)
    }

    // MARK: Tokenizer

    private func tokenize() throws -> [Token] {
        var tokens = [Token(kind: .startOfLine, text: "", start: 0, end: 0)]
        var pending: Token?
        var index = 0
        while index < characters.count {
            let start = index
            var character = characters[index]
            let kind: TokenKind
            if character == .escapeCharacter {
                guard index + 1 < characters.count else { throw error(.escapedEndOfLine, index, index + 1) }
                character = characters[index + 1]
                guard canEscape(character) else { throw error(.cannotEscape, index + 1, index + 2) }
                kind = .text
                index += 2
            } else {
                kind = tokenKind(of: character)
                index += 1
            }
            // Runs of text and of whitespace are one token each; every other token is one character.
            if var token = pending, token.kind == kind, kind == .text || kind == .whitespace {
                token.text.append(character)
                token.end = index
                pending = token
            } else {
                if let token = pending { tokens.append(token) }
                pending = Token(kind: kind, text: String(character), start: start, end: index)
            }
        }
        if let token = pending { tokens.append(token) }
        tokens.append(Token(kind: .endOfLine, text: "", start: characters.count, end: characters.count))
        return tokens
    }

    private func canEscape(_ character: Character) -> Bool {
        // Whitespace, `{`, `}`, `(`, `)`, `/` and `\`.
        tokenKind(of: character) != .text || character == .escapeCharacter
    }

    private func tokenKind(of character: Character) -> TokenKind {
        switch character {
            case _ where character.isWhitespace: return .whitespace
            case .leadingOptionalBoundary: return .beginOptional
            case .trailingOptionalBoundary: return .endOptional
            case .leadingParameterBoundary: return .beginParameter
            case .trailingParameterBoundary: return .endParameter
            case .alternateSeparator: return .alternation
            default: return .text
        }
    }

    // MARK: Parser

    private func parse(_ rule: Rule, _ tokens: [Token], at current: Int) throws -> Result {
        switch rule {
            case .text:
                // text := whitespace | ')' | '}' | .
                let token = tokens[current]
                switch token.kind {
                    case .whitespace, .text, .endParameter, .endOptional:
                        return (1, [Node(kind: .text, start: token.start, end: token.end, token: token.text)])
                    case .alternation:
                        throw error(.alternationInOptional, token.start, token.end)
                    default:
                        return (0, [])
                }
            case .name:
                // name := whitespace | .
                let token = tokens[current]
                switch token.kind {
                    case .whitespace, .text:
                        return (1, [Node(kind: .text, start: token.start, end: token.end, token: token.text)])
                    case .beginOptional, .endOptional, .beginParameter, .endParameter, .alternation:
                        throw error(.invalidParameterName, token.start, token.end)
                    default:
                        return (0, [])
                }
            case .parameter:
                // parameter := '{' + name* + '}'
                return try parseBetween(.parameter, .beginParameter, .endParameter, [.name], tokens, at: current)
            case .optional:
                // optional := '(' + option* + ')'
                // option := optional | parameter | text
                return try parseBetween(.optional, .beginOptional, .endOptional, Self.optionRules, tokens, at: current)
            case .alternativeSeparator:
                guard lookingAt(tokens, current, .alternation) else { return (0, []) }
                let token = tokens[current]
                return (1, [Node(kind: .alternative, start: token.start, end: token.end, token: token.text)])
            case .alternation:
                return try parseAlternation(tokens, at: current)
            case .expression:
                // cucumber-expression := ( alternation | optional | parameter | text )*
                return try parseBetween(.expression, .startOfLine, .endOfLine, Self.expressionRules, tokens, at: current)
        }
    }

    /// alternation := (?<=left-boundary) + alternative* + ( '/' + alternative* )+ + (?=right-boundary)
    /// left-boundary := whitespace | } | ^
    /// right-boundary := whitespace | { | $
    /// alternative: = optional | parameter | text
    private func parseAlternation(_ tokens: [Token], at current: Int) throws -> Result {
        guard lookingAt(tokens, current - 1, .startOfLine, .whitespace, .endParameter) else { return (0, []) }
        let rightBoundaries: [TokenKind] = [.whitespace, .endOfLine, .beginParameter]
        let result = try parseTokens(until: rightBoundaries, with: Self.alternativeRules, tokens, at: current)
        guard result.nodes.contains(where: { $0.kind == .alternative }) else { return (0, []) }
        let start = tokens[current].start
        // The right-hand boundary is not consumed.
        let end = tokens[current + result.consumed].start
        let alternatives = splitAlternatives(start, end, result.nodes)
        return (result.consumed, [Node(kind: .alternation, start: start, end: end, children: alternatives)])
    }

    private func parseBetween(_ kind: Node.Kind,
                              _ begin: TokenKind,
                              _ end: TokenKind,
                              _ rules: [Rule],
                              _ tokens: [Token],
                              at current: Int) throws -> Result {
        guard lookingAt(tokens, current, begin) else { return (0, []) }
        let result = try parseTokens(until: [end, .endOfLine], with: rules, tokens, at: current + 1)
        let last = current + 1 + result.consumed
        guard lookingAt(tokens, last, end) else {
            let problem: CucumberExpression.SyntaxError.Problem = begin == .beginParameter ? .missingClosingBrace
                                                                                            : .missingClosingParenthesis
            throw error(problem, tokens[current].start, tokens[current].end)
        }
        let node = Node(kind: kind, start: tokens[current].start, end: tokens[last].end, children: result.nodes)
        return (last + 1 - current, [node])
    }

    private func parseTokens(until endKinds: [TokenKind],
                             with rules: [Rule],
                             _ tokens: [Token],
                             at start: Int) throws -> Result {
        var current = start
        var nodes = [Node]()
        while current < tokens.count, !endKinds.contains(where: { lookingAt(tokens, current, $0) }) {
            var result: Result = (0, [])
            for rule in rules {
                result = try parse(rule, tokens, at: current)
                if result.consumed != 0 { break }
            }
            // Every token is accepted by one of the rules, so this only stops an endless loop.
            guard result.consumed != 0 else { break }
            current += result.consumed
            nodes += result.nodes
        }
        return (current - start, nodes)
    }

    private func lookingAt(_ tokens: [Token], _ index: Int, _ kinds: TokenKind...) -> Bool {
        let kind: TokenKind
        if index < 0 {
            kind = .startOfLine
        } else if index >= tokens.count {
            kind = .endOfLine
        } else {
            kind = tokens[index].kind
        }
        return kinds.contains(kind)
    }

    /// Groups the nodes of an alternation into one alternative node per side of each `/`.
    private func splitAlternatives(_ start: Int, _ end: Int, _ nodes: [Node]) -> [Node] {
        var separators = [Node]()
        var alternatives = [[Node]()]
        for node in nodes {
            if node.kind == .alternative {
                separators.append(node)
                alternatives.append([])
            } else {
                alternatives[alternatives.count - 1].append(node)
            }
        }
        return alternatives.enumerated().map { offset, children in
            let alternativeStart = offset == 0 ? start : separators[offset - 1].end
            let alternativeEnd = offset == separators.count ? end : separators[offset].start
            return Node(kind: .alternative, start: alternativeStart, end: alternativeEnd, children: children)
        }
    }

    // MARK: Checks

    /// The checks cucumber-jvm makes while it turns the tree into a regular expression, in the same
    /// order, collecting the parameters as it goes.
    private func check(_ node: Node, collecting parameters: inout [Node]) throws {
        switch node.kind {
            case .optional:
                if let parameter = node.children.first(where: { $0.kind == .parameter }) {
                    throw error(.parameterInOptional, parameter.start, parameter.end)
                }
                if let optional = node.children.first(where: { $0.kind == .optional }) {
                    throw error(.optionalInOptional, optional.start, optional.end)
                }
                if !node.children.contains(where: { $0.kind == .text }) {
                    throw error(.emptyOptional, node.start, node.end)
                }
            case .alternation:
                for alternative in node.children {
                    if alternative.children.isEmpty {
                        throw error(.emptyAlternative, alternative.start, alternative.end)
                    }
                    if !alternative.children.contains(where: { $0.kind == .text }) {
                        throw error(.alternativeWithOnlyOptionals, alternative.start, alternative.end)
                    }
                }
            case .parameter:
                parameters.append(node)
                return
            case .text, .alternative, .expression:
                break
        }
        for child in node.children {
            try check(child, collecting: &parameters)
        }
    }
}
