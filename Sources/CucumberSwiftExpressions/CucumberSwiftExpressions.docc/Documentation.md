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

## Installation

### Swift Package Manager

Add the package to the dependencies in your `Package.swift`, and the library to your target:

```swift
dependencies: [
    .package(url: "https://github.com/cucumberswift/CucumberSwiftExpressions.git", from: "1.2.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: ["CucumberSwiftExpressions"]),
]
```

### Bazel

CucumberSwiftExpressions is a Bazel module named `cucumberswift_expressions`. Add it to your `MODULE.bazel`, with the latest version from the [Bazel Central Registry](https://registry.bazel.build/modules/cucumberswift_expressions) in place of `X.Y.Z`:

> Note: CucumberSwiftExpressions is not on the Bazel Central Registry yet. The first version published there will be the first release that includes the Bazel files, and this section applies from then on.

```starlark
bazel_dep(name = "cucumberswift_expressions", version = "X.Y.Z")
```

Then depend on its `swift_library` from your target in `BUILD.bazel`:

```starlark
deps = ["@cucumberswift_expressions//:CucumberSwiftExpressions"],
```

The module uses [rules_swift](https://github.com/bazelbuild/rules_swift), and is tested with the Bazel version in its `.bazelversion`.
