"""A macOS test runner that runs the test bundle with `xcrun xctest`.

`rules_apple`'s macOS runner runs tests with `xcodebuild test-without-building`,
which needs the com.apple.testmanagerd service. This one runs the bundle
directly with Apple's `xctest` tool, so it works where that service is not
available, such as the Bazel Central Registry's presubmit agents. It is the same
runner as CucumberSwift's Tests/xctest_runner.bzl.
"""

load("@rules_apple//apple:providers.bzl", "apple_provider")

def _macos_xctest_runner_impl(ctx):
    return [
        apple_provider.make_apple_test_runner_info(
            test_runner_template = ctx.file._test_template,
            execution_requirements = {"requires-darwin": ""},
        ),
        DefaultInfo(),
    ]

macos_xctest_runner = rule(
    implementation = _macos_xctest_runner_impl,
    attrs = {
        "_test_template": attr.label(
            default = Label(":xctest_runner.template.sh"),
            allow_single_file = True,
        ),
    },
    doc = "Runs a macos_unit_test's bundle with `xcrun xctest`. Pass it as the test's `runner`.",
)
