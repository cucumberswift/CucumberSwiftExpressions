![Build Status](https://github.com/cucumberswift/CucumberSwiftExpressions/actions/workflows/CI.yml/badge.svg?branch=main)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=cucumberswift_CucumberSwiftExpressions&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=cucumberswift_CucumberSwiftExpressions)

# CucumberSwiftExpressions

CucumberSwiftExpressions parses Cucumber expressions and matches them against step text. A Cucumber expression is a simpler way to match step text than a regular expression. You write `I have {int} cukes` instead of `^I have (-?\d+) cukes$`. [CucumberSwift](https://github.com/cucumberswift/CucumberSwift) uses this library, and you can also use it on its own.

```swift
import CucumberSwiftExpressions

let expression = CucumberExpression("I have {int} cukes")
if let match = expression.match(in: "I have 7 cukes") {
    let count = try match.first(\.int) // 7
}
```

### Cucumber expressions and regular expressions

`CucumberExpression` accepts a Cucumber expression or a regular expression. It tells them apart in the same way as Cucumber's reference implementation:

- A string that starts with `^` or ends with `$` is a regular expression.
- A string written between slashes, like `/I have (\d+) cukes/`, is a regular expression. The slashes are not part of the pattern.
- Anything else is a Cucumber expression.

In a regular expression, each top-level capture group becomes an anonymous parameter.

### Invalid regular expressions

The `CucumberExpression(validating:)` initializer throws when a string is treated as a regular expression that doesn't compile. Use it to handle the error with `try`:

```swift
do {
    let expression = try CucumberExpression(validating: "^I have (\\d+ cukes$")
} catch {
    print(error)
}
```

The plain `CucumberExpression(_:)` initializer doesn't crash on such a string. Its `invalidRegularExpression` property says what is wrong, for example `expected ')'`. If you call `match(in:)` anyway, it traps.

### Checking an expression without matching text

To check an expression without matching any text, for example while a step definition compiles, create a `CucumberExpression.Syntax` with `CucumberExpression.Syntax(parsing:)`. The syntax lists the arguments that a match passes, in order. Each argument has its parameter name and its range in the string.

```swift
let syntax = try CucumberExpression.Syntax(parsing: "I have {int} cukes")
let names = syntax.arguments.map(\.parameterName) // ["int"]
```

A Cucumber expression that doesn't follow the specification, such as `I have {int cukes`, throws a `CucumberExpression.SyntaxError`. The error has cucumber-jvm's message and the range of the problem. A parameter name that isn't built in is an argument, not an error, because you register custom parameters at run time. The plain `CucumberExpression(_:)` initializer doesn't run this check.

## Installation

### Swift Package Manager

Add the package to the dependencies in your `Package.swift`, and the library to your target:

```swift
dependencies: [
    .package(url: "https://github.com/cucumberswift/CucumberSwiftExpressions.git", from: "1.4.2"),
],
targets: [
    .target(name: "MyTarget", dependencies: ["CucumberSwiftExpressions"]),
]
```

### Bazel

CucumberSwiftExpressions is a Bazel module named `cucumberswift_expressions`. Add it to your `MODULE.bazel`, with the latest version from the [Bazel Central Registry](https://registry.bazel.build/modules/cucumberswift_expressions) in place of `X.Y.Z`:

```starlark
bazel_dep(name = "cucumberswift_expressions", version = "X.Y.Z")
```

Then depend on its `swift_library` from your target in `BUILD.bazel`:

```starlark
deps = ["@cucumberswift_expressions//:CucumberSwiftExpressions"],
```

The module uses [rules_swift](https://github.com/bazelbuild/rules_swift). Its tests run with the Bazel version in its `.bazelversion`.

The [documentation](https://cucumberswift.org/CucumberSwiftExpressions/documentation/cucumberswiftexpressions/) has more detail.

## Attributions

The grammar of Cucumber expressions, and how to implement them, come from [cucumber-expressions](https://github.com/cucumber/cucumber-expressions).

[This static website](https://cucumber.github.io/cucumber-expressions/) let me try unusual edge cases, to see the expected behavior and the correct regular expressions.
