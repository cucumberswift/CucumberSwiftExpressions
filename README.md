![Build Status](https://github.com/cucumberswift/CucumberSwiftExpressions/actions/workflows/CI.yml/badge.svg?branch=main)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=cucumberswift_CucumberSwiftExpressions&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=cucumberswift_CucumberSwiftExpressions)

# CucumberSwiftExpressions

Cucumber expressions are a simpler alternative to regular expressions for matching step text: `I have {int} cukes` instead of `^I have (-?\d+) cukes$`. This library parses and matches them in Swift. [CucumberSwift](https://github.com/cucumberswift/CucumberSwift) uses it, and it also works as a standalone library.

A `CucumberExpression` accepts either kind of pattern, and tells them apart the same way Cucumber's reference implementation does:

- A string that starts with `^` or ends with `$` is a regular expression.
- A string written between slashes, like `/I have (\d+) cukes/`, is a regular expression. The slashes are not part of the pattern.
- Anything else is a Cucumber expression.

In a regular expression, each top-level capture group becomes an anonymous parameter.

If a string is treated as a regular expression but will not compile, creating the expression does not crash. `invalidRegularExpression` says what is wrong, for example `expected ')'`, and `match(in:)` traps if you call it anyway. To handle the error with `try` instead, use `CucumberExpression(validating:)`.

[Check out the docs](https://cucumberswift.org/CucumberSwiftExpressions/documentation/cucumberswiftexpressions/) for more info.

## Attributions
Cucumber Expressions grammar and implementation information came from [cucumber-expressions](https://github.com/cucumber/cucumber-expressions). 

[This static website](https://cucumber.github.io/cucumber-expressions/) allowed me to play with weird edge cases to see expected behavior and correct regex outputs.