//
//  Syntax.swift
//  CucumberSwiftExpressions
//

import Foundation

extension CucumberExpression {
    /// What an expression's arguments are, worked out without matching any text, for a caller such as
    /// a compile-time check that wants to know what a step definition receives.
    ///
    /// Creating it checks the expression strictly, following the Cucumber Expressions specification
    /// and cucumber-jvm: a Cucumber expression with a syntax error, such as `I have {int cukes`,
    /// throws ``CucumberExpression/SyntaxError``. ``CucumberExpression/init(_:)`` does not change: it
    /// stays lenient, and matches such an expression as it always has.
    ///
    /// A parameter whose name is not built in is an argument, not an error, because custom parameters
    /// are registered at run time through ``CustomParameters``.
    public struct Syntax: Equatable {
        /// How the string is read, by the same rule as ``CucumberExpression/init(_:)``.
        public enum Kind: Equatable {
            /// A Cucumber expression, such as `I have {int} cukes`.
            case cucumberExpression
            /// A regular expression: the string starts with `^`, ends with `$` or is written between
            /// slashes.
            case regularExpression
        }

        /// The string this describes.
        public let expression: String
        public let kind: Kind
        /// The arguments a match passes, in order: one per parameter of a Cucumber expression, or one
        /// per top-level capture group of a regular expression, counted as ``CucumberExpression/match(in:)``
        /// counts them.
        public let arguments: [Argument]

        /// Describes `expression`, or throws if it is not valid.
        /// - Throws: ``CucumberExpression/SyntaxError`` for a Cucumber expression that does not parse,
        ///   and ``InvalidRegularExpression`` for a regular expression that will not compile.
        public init(parsing expression: String) throws {
            self.expression = expression
            let compiled = try CucumberExpression(validating: expression)
            if let groups = compiled.captureGroups {
                kind = .regularExpression
                arguments = Self.arguments(for: groups, in: expression)
            } else {
                kind = .cucumberExpression
                arguments = try SyntaxParser(expression).arguments()
            }
        }

        private static func arguments(for groups: [CaptureGroup], in expression: String) -> [Argument] {
            let offset = CucumberExpression.isBetweenSlashes(expression) ? 1 : 0
            let indices = Array(expression.indices) + [expression.endIndex]
            let wholePattern = indices[offset]..<indices[indices.count - 1 - offset]
            return groups.map { group in
                // A group the scanner could not place covers the whole pattern.
                let range = group.characters.map { indices[$0.lowerBound + offset]..<indices[$0.upperBound + offset] }
                return Argument(parameterName: AnonymousParameter.name, range: range ?? wholePattern)
            }
        }
    }

    /// One argument a match passes.
    public struct Argument: Hashable {
        /// The parameter's name: `int`, `string`, a custom name, or an empty string (the name of
        /// ``AnonymousParameter``) for `{}` and for a regular expression's capture group.
        public let parameterName: String
        /// Where the argument is written in ``Syntax/expression``: a parameter including its braces,
        /// such as `{int}`, or a capture group including its parentheses.
        public let range: Range<String.Index>
    }
}
