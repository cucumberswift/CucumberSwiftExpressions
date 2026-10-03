//
//  SyntaxError.swift
//  CucumberSwiftExpressions
//

import Foundation

extension CucumberExpression {
    /// What is wrong with a Cucumber expression that does not parse, thrown by
    /// ``CucumberExpression/Syntax/init(parsing:)``.
    ///
    /// The problems, messages and ranges are those of the Cucumber Expressions specification, as
    /// cucumber-jvm reports them. Only the first problem is reported, because the rest of an expression
    /// cannot be read reliably after one.
    public struct SyntaxError: Error, Equatable, CustomStringConvertible {
        public enum Problem: Equatable {
            /// A `{` with no `}` after it, such as `I have {int cukes`. The range is the `{`.
            case missingClosingBrace
            /// A `(` with no `)` after it. The range is the `(`.
            case missingClosingParenthesis
            /// `{`, `}`, `(`, `)` or `/` inside a parameter's name, such as `{(string)}`. The range is
            /// that character.
            case invalidParameterName
            /// A parameter inside optional text, such as `({int})`. The range is the parameter.
            case parameterInOptional
            /// Optional text inside optional text, such as `(a(b))`. The range is the inner optional.
            case optionalInOptional
            /// Optional text with no text in it, such as `()`. The range is the optional.
            case emptyOptional
            /// A `/` inside optional text, such as `( brown/black)`. The range is the `/`.
            case alternationInOptional
            /// An alternation with an empty side, such as `brown//black` or `x/{int}`. The range is the
            /// empty alternative, so it is empty: the place where its text is missing.
            case emptyAlternative
            /// An alternative made only of optional text, such as `(brown)/black`. The range is the
            /// alternative.
            case alternativeWithOnlyOptionals
            /// A `\` before a character that cannot be escaped, such as `\[`. The range is that character.
            case cannotEscape
            /// A `\` at the end of the expression. The range is the `\`.
            case escapedEndOfLine
        }

        /// The string that does not parse.
        public let expression: String
        public let problem: Problem
        /// Where the problem is in ``expression``; each ``Problem`` says what it covers.
        public let range: Range<String.Index>
        /// What is wrong, such as "The '{' does not have a matching '}'".
        public let message: String
        /// How to fix it, such as "If you did not intend to use a parameter you can use '\{' to escape the
        /// a parameter".
        public let solution: String

        /// The full report, laid out as cucumber-jvm lays it out: the column (counted in characters),
        /// the expression, a pointer under the problem, the message and the solution.
        public var description: String {
            let start = expression.distance(from: expression.startIndex, to: range.lowerBound)
            let length = expression.distance(from: range.lowerBound, to: range.upperBound)
            var pointer = String(repeating: " ", count: start) + "^"
            if length > 1 {
                pointer += String(repeating: "-", count: length - 2) + "^"
            }
            return """
            This Cucumber Expression has a problem at column \(start + 1):

            \(expression)
            \(pointer)
            \(message).
            \(solution)
            """
        }

        init(_ problem: Problem, at characters: Range<Int>, in expression: String) {
            self.expression = expression
            self.problem = problem
            let lowerBound = expression.index(expression.startIndex, offsetBy: characters.lowerBound)
            range = lowerBound..<expression.index(lowerBound, offsetBy: characters.count)
            (message, solution) = Self.text(for: problem)
        }

        // The text is cucumber-jvm's, word for word, so it matches the specification's test data.
        private static func text(for problem: Problem) -> (message: String, solution: String) {
            switch problem {
                case .missingClosingBrace:
                    return ("The '{' does not have a matching '}'",
                            #"If you did not intend to use a parameter you can use '\{' to escape the a parameter"#)
                case .missingClosingParenthesis:
                    return ("The '(' does not have a matching ')'",
                            #"If you did not intend to use optional text you can use '\(' to escape the optional text"#)
                case .invalidParameterName:
                    return (#"Parameter names may not contain '{', '}', '(', ')', '\' or '/'"#,
                            "Did you mean to use a regular expression?")
                case .parameterInOptional:
                    return ("An optional may not contain a parameter type",
                            #"If you did not mean to use an parameter type you can use '\{' to escape the '{'"#)
                case .optionalInOptional:
                    return ("An optional may not contain an other optional",
                            #"If you did not mean to use an optional type you can use '\(' to escape the '('. "#
                                + "For more complicated expressions consider using a regular expression instead.")
                case .emptyOptional:
                    return ("An optional must contain some text",
                            #"If you did not mean to use an optional you can use '\(' to escape the '('"#)
                case .alternationInOptional:
                    return ("An alternation can not be used inside an optional",
                            #"If you did not mean to use an alternation you can use '\/' to escape the '/'. "#
                                + "Otherwise rephrase your expression or consider using a regular expression instead.")
                case .emptyAlternative:
                    return ("Alternative may not be empty",
                            #"If you did not mean to use an alternative you can use '\/' to escape the '/'"#)
                case .alternativeWithOnlyOptionals:
                    return ("An alternative may not exclusively contain optionals",
                            #"If you did not mean to use an optional you can use '\(' to escape the '('"#)
                case .cannotEscape:
                    return (#"Only the characters '{', '}', '(', ')', '\', '/' and whitespace can be escaped"#,
                            #"If you did mean to use an '\' you can use '\\' to escape it"#)
                case .escapedEndOfLine:
                    return ("The end of line can not be escaped",
                            #"You can use '\\' to escape the '\'"#)
            }
        }
    }
}
