### Contributing

Let's keep this short and sweet. So you want to contribute to CucumberSwift? Cool! There are 3 things required to do so:

- Be available for questions. If there's confusion about what you wrote or why you wrote it that way we need to be able to talk about it before it makes it into main.
- TEST YOUR CODE! CucumberSwift is primarily black-box tested, that's fine. Feel free to unit test as well, the point is the testing framework really ought to be tested.
- Submit a Pull Request. At this point you've got everything tested, your new feature or bug fix is in place and you know you'll be near your email for the next few days. Submit your PR and we'll get it turned around and into main ASAP

**Breaking changes need a migration note.** If users have to change something to upgrade, the issue body gets a `## Migration` section that says what to change, with an example. The release notes copy it under the issue's entry, and a release refuses to start while an issue labelled `breaking` has none. Any other issue can have one too, for example when an install channel goes away. Keep it to what users must do; the background belongs in the rest of the issue.


**Bazel.** The package is also a Bazel module (`MODULE.bazel`, `BUILD.bazel`). Its tests are a second module in `Tests/`, which depends on the package the way a Bazel project would, so CI's `Bazel tests` job checks the package as a dependency. With [Bazelisk](https://github.com/bazelbuild/bazelisk) installed (`brew install bazelisk`), which runs the Bazel version in `.bazelversion`, run `bazelisk test //...` from the `Tests` folder. That runs the tests on macOS and on an iOS simulator (which needs an iOS simulator runtime installed in Xcode). CI also runs them on the oldest Bazel major that `MODULE.bazel` allows, against a `git archive` of the commit, as the release archive contains it. A new source or test file needs no change, because the BUILD files glob the folders. A new dependency in `Package.swift` needs a `bazel_dep` in `MODULE.bazel` too. When you add tests, raise `MIN_TESTS` in `CI.yml`.

I realize this document is somewhat lacking in terms of process, for now I don't care. If we start seeing more contributors I'll think through more how this should work.