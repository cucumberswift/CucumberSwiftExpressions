![Build Status](https://github.com/cucumberswift/CucumberSwiftExpressions/actions/workflows/CI.yml/badge.svg?branch=main)

# CucumberSwiftExpressions

Cucumber expressions are a simpler alternative to regular expressions for matching step text: `I have {int} cukes` instead of `^I have (-?\d+) cukes$`. This library parses and matches them in Swift. [CucumberSwift](https://github.com/cucumberswift/CucumberSwift) uses it, and it also works as a standalone library.

A `CucumberExpression` accepts either kind of pattern, and tells them apart the same way Cucumber's reference implementation does:

- A string that starts with `^` or ends with `$` is a regular expression.
- A string written between slashes, like `/I have (\d+) cukes/`, is a regular expression. The slashes are not part of the pattern.
- Anything else is a Cucumber expression.

In a regular expression, each top-level capture group becomes an anonymous parameter.

[Check out the docs](https://cucumberswift.org/CucumberSwiftExpressions/documentation/cucumberswiftexpressions/) for more info.

## Attributions
Cucumber Expressions grammar and implementation information came from [cucumber-expressions](https://github.com/cucumber/cucumber-expressions). 

[This static website](https://cucumber.github.io/cucumber-expressions/) allowed me to play with weird edge cases to see expected behavior and correct regex outputs.