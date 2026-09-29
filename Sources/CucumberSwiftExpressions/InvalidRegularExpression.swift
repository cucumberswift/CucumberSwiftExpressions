//
//  InvalidRegularExpression.swift
//  CucumberSwiftExpressions
//

import Foundation

/// A ``CucumberExpression`` that is treated as a regular expression, because it starts with `^`, ends
/// with `$` or is written between slashes, but whose pattern will not compile.
public struct InvalidRegularExpression: Error, Equatable, CustomStringConvertible {
    /// The string the expression was created from.
    public let expression: String
    /// The pattern that was compiled: ``expression`` without its slashes, if it had them.
    public let pattern: String
    /// What is wrong with ``pattern``, such as "expected ')'". Where Swift's own regular expression
    /// parser is not available (before macOS 13, iOS 16, tvOS 16 and watchOS 9), this is Foundation's
    /// less specific description.
    public let problem: String
    let treatedAsRegularExpressionBecause: String
    let fix: String

    /// The full message: why the expression is a regular expression, what is wrong with it, and how
    /// to fix it.
    public var description: String {
        """
        CucumberExpression: "\(expression)" \(treatedAsRegularExpressionBecause), so it is treated as a \
        regular expression, but it is not valid as one: \(problem). \(fix)
        """
    }
}
