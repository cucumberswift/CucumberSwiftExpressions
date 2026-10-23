# Contributing to CucumberSwiftExpressions

Thank you for contributing to CucumberSwiftExpressions. A contribution needs three things:

- **Be available for questions.** If there's confusion about what you wrote, or why, we need to talk about it before it goes into `main`.
- **Test your code.** The package is mostly black-box tested, and that's fine. You can add unit tests too. The point is that a testing framework ought to be tested.
- **Open a pull request** once your change is in place and tested, and you know you'll be near your email for the next few days. We'll review it and get it into `main` as soon as we can.

## Breaking changes need a migration note

If users have to change something to upgrade, add a `## Migration` section to the issue body. It says what to change, with an example. The release notes copy it under the issue's entry. A release doesn't start while an issue labelled `breaking` has no migration note.

Any other issue can have a migration note too, for example when an install channel goes away. Keep it to what users must do. The background belongs in the rest of the issue.

## Testing with Bazel

The package is also a Bazel module (`MODULE.bazel`, `BUILD.bazel`). Its tests are a second module in `Tests/`. That module depends on the package in the way a Bazel project would, so CI's `Bazel tests` job checks the package as a dependency.

To run the tests, install [Bazelisk](https://github.com/bazelbuild/bazelisk) (`brew install bazelisk`), which runs the Bazel version in `.bazelversion`. Then run this from the `Tests` folder:

```bash
bazelisk test //...
```

The command runs the tests on macOS, with `xcrun xctest` through the runner in `Tests/xctest_runner.bzl`. It also runs them on an iOS simulator, which needs an iOS simulator runtime installed in Xcode.

`.bcr/presubmit.yml` is the presubmit that each Bazel Central Registry entry runs. It runs the macOS tests from `Tests`. CI also runs the tests on the oldest Bazel major version that `MODULE.bazel` allows. It runs them against a `git archive` of the commit, which is what the release archive contains.

When you change the package, keep these points in mind:

- A new source or test file needs no change, because the BUILD files glob the folders.
- A new dependency in `Package.swift` needs a `bazel_dep` in `MODULE.bazel` too.
- When you add tests, raise `MIN_TESTS` in `CI.yml`.

## More process later

The contributing guide is light on process, and that's fine for now. If more people start contributing, I'll think more about how this should work.
