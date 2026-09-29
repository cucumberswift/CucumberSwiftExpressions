# ``CucumberSwiftExpressions``

A cucumber expressions implementation in Swift.

## Overview

Cucumber expressions are a simpler alternative to regular expressions for matching step text: `I have {int} cukes` instead of `^I have (-?\d+) cukes$`. This library parses and matches them in Swift. CucumberSwift uses it, and it also works as a standalone library.

A `CucumberExpression` accepts either kind of pattern, and tells them apart the same way Cucumber's reference implementation does:

- A string that starts with `^` or ends with `$` is a regular expression.
- A string written between slashes, like `/I have (\d+) cukes/`, is a regular expression. The slashes are not part of the pattern.
- Anything else is a Cucumber expression.

In a regular expression, each top-level capture group becomes an anonymous parameter.

If a string is treated as a regular expression but will not compile, creating the expression does not crash. ``CucumberExpression/invalidRegularExpression`` says what is wrong, for example `expected ')'`, and ``CucumberExpression/match(in:)`` traps if you call it anyway. To handle the error with `try` instead, use ``CucumberExpression/init(validating:)``.
