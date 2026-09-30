"""Unit tests for check_lockfiles.py.

Run from the repository root:

  python3 -m unittest discover -s .github/scripts -v

Each test writes its own Package.swift and Package.resolved to a temporary
directory, and swift and git are replaced with fakes, so the tests need no
network access, toolchain or checkout. Only the standard library is used.
"""
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_lockfiles  # noqa: E402

DOCC = "https://github.com/apple/swift-docc-plugin"
SYMBOLKIT = "https://github.com/swiftlang/swift-docc-symbolkit"
DOCC_100 = "3303b164430d9a7055ba484c8ead67a52f7b74f6"


def package_swift(docc='from: "1.0.0"'):
    return f"""// swift-tools-version: 5.5
// A comment with a URL: https://example.com/not-a-dependency.git
import PackageDescription

let package = Package(
    name: "CucumberSwiftExpressions",
    dependencies: [
        .package(url: "{DOCC}", {docc}) // trailing comment
    ],
    targets: [
        .target(name: "CucumberSwiftExpressions", dependencies: [])
    ]
)
"""


def resolved_v1(pins):
    """A lockfile in format 1, as tools version 5.5 writes. `pins` is a list of
    (name, url, version, revision)."""
    return json.dumps({"object": {"pins": [
        {"package": name, "repositoryURL": url,
         "state": {"branch": None if version else "main", "revision": revision, "version": version}}
        for name, url, version, revision in pins]}, "version": 1}, indent=2)


def resolved_v3(pins):
    """A lockfile in format 3, as a newer tools version writes."""
    return json.dumps({"originHash": "0" * 64, "pins": [
        {"identity": check_lockfiles.identity(url), "kind": "remoteSourceControl",
         "location": url, "state": {"revision": revision, "version": version}}
        for _, url, version, revision in pins], "version": 3}, indent=2)


PINS = [("SwiftDocCPlugin", DOCC, "1.0.0", DOCC_100)]


class Repository(unittest.TestCase):
    """A temporary working directory holding the two files, as on main."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.previous = os.getcwd()
        os.chdir(self.directory.name)
        self.addCleanup(os.chdir, self.previous)
        self.write(check_lockfiles.PACKAGE_SWIFT, package_swift())
        self.write(check_lockfiles.PACKAGE_RESOLVED, resolved_v1(PINS))

    def write(self, path, text):
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)

    def main(self, *argv):
        out = io.StringIO()
        with redirect_stdout(out):
            status = check_lockfiles.main(list(argv))
        return status, out.getvalue()

    def errors(self, output):
        return [line for line in output.splitlines() if line.startswith("::error::")]


class PassingTests(Repository):
    def test_the_files_as_on_main_pass(self):
        status, output = self.main()
        self.assertEqual(status, 0)
        self.assertEqual(self.errors(output), [])
        self.assertIn("Package.swift agrees with Package.resolved.", output)

    def test_a_transitive_pin_is_not_checked(self):
        # Only direct dependencies have a lower bound in Package.swift.
        self.write(check_lockfiles.PACKAGE_RESOLVED, resolved_v1(
            PINS + [("SymbolKit", SYMBOLKIT, "1.0.0", "c" * 40)]))
        self.assertEqual(check_lockfiles.check_files(), [])

    def test_a_newer_lockfile_format_passes(self):
        self.write(check_lockfiles.PACKAGE_RESOLVED, resolved_v3(PINS))
        self.assertEqual(check_lockfiles.check_files(), [])


class LowerBoundTests(Repository):
    def test_a_lower_bound_below_its_pin_fails(self):
        # What a Dependabot update within range leaves: Package.resolved moves,
        # Package.swift does not.
        self.write(check_lockfiles.PACKAGE_RESOLVED, resolved_v1(
            [("SwiftDocCPlugin", DOCC, "1.4.0", "b" * 40)]))
        status, output = self.main()
        self.assertEqual(status, 1)
        [error] = self.errors(output)
        self.assertIn(f"Package.swift requires {DOCC} from 1.0.0, but Package.resolved pins 1.4.0", error)
        self.assertIn("Set the lower bound in Package.swift to 1.4.0", error)
        self.assertIn("run `swift package resolve` and commit Package.resolved", error)

    def test_a_lower_bound_above_its_pin_fails(self):
        self.write(check_lockfiles.PACKAGE_SWIFT, package_swift(docc='from: "1.1.0"'))
        [error] = check_lockfiles.check_files()
        self.assertIn(f"Package.swift requires {DOCC} from 1.1.0, but Package.resolved pins 1.0.0", error)

    def test_a_dependency_missing_from_its_lockfile_fails(self):
        self.write(check_lockfiles.PACKAGE_RESOLVED, resolved_v1([]))
        status, output = self.main()
        self.assertEqual(status, 1)
        [error] = self.errors(output)
        self.assertIn(f"Package.resolved has no pin for {DOCC}, which Package.swift requires", error)

    def test_a_dependency_pinned_to_a_branch_fails(self):
        self.write(check_lockfiles.PACKAGE_RESOLVED, resolved_v1(
            [("SwiftDocCPlugin", DOCC, None, DOCC_100)]))
        [error] = check_lockfiles.check_files()
        self.assertIn(f"Package.resolved pins {DOCC} to a branch or revision, not a version", error)

    def test_a_requirement_without_a_version_fails(self):
        self.write(check_lockfiles.PACKAGE_SWIFT, package_swift(docc='branch: "main"'))
        status, output = self.main()
        self.assertEqual(status, 1)
        [error] = self.errors(output)
        self.assertIn(f"{DOCC} has no version requirement this check can read", error)


class RepositoryURLTests(Repository):
    def test_a_pin_from_another_owner_with_the_same_identity_fails(self):
        fork = "https://github.com/someone-else/swift-docc-plugin.git"
        self.write(check_lockfiles.PACKAGE_RESOLVED, resolved_v1(
            [("SwiftDocCPlugin", fork, "1.0.0", DOCC_100)]))
        [error] = check_lockfiles.check_files()
        self.assertIn(f"Package.swift requires {DOCC}, but Package.resolved pins {fork}, "
                      f"a different repository", error)

    def test_urls_that_differ_only_in_case_and_git_suffix_are_the_same_package(self):
        self.write(check_lockfiles.PACKAGE_RESOLVED, resolved_v1(
            [("SwiftDocCPlugin", "https://github.com/Apple/Swift-DocC-Plugin.git", "1.0.0", DOCC_100)]))
        self.assertEqual(check_lockfiles.check_files(), [])


class ParsingTests(unittest.TestCase):
    def test_every_version_requirement_form_gives_its_lower_bound(self):
        for requirement, bound in [
            ('from: "1.2.0"', "1.2.0"),
            ('.upToNextMajor(from: "1.2.0")', "1.2.0"),
            ('.upToNextMinor(from: "1.2.0")', "1.2.0"),
            ('exact: "1.2.0"', "1.2.0"),
            ('.exact("1.2.0")', "1.2.0"),
            ('"1.2.0"..<"2.0.0"', "1.2.0"),
            ('"1.2.0"..."1.9.9"', "1.2.0"),
        ]:
            with self.subTest(requirement):
                parsed = check_lockfiles.parse_package_swift(package_swift(docc=requirement))
                self.assertEqual(parsed["swift-docc-plugin"], (DOCC, bound))

    def test_a_named_package_and_a_local_package(self):
        text = """
        dependencies: [
            .package(name: "Foo", url: "https://example.com/Foo.git", .upToNextMajor(from: "2.0.0")),
            .package(path: "../Local")
        ]
        """
        self.assertEqual(check_lockfiles.parse_package_swift(text),
                         {"foo": ("https://example.com/Foo.git", "2.0.0")})

    def test_a_dependency_in_a_block_comment_is_ignored(self):
        # A commented-out dependency has no pin, and must not be reported as missing one.
        for comment in [
            '/* .package(url: "https://example.com/Gone.git", from: "1.0.0"), */',
            '/* outer /* nested */ .package(url: "https://example.com/Gone.git", from: "1.0.0"), */',
            '/*\n        .package(url: "https://example.com/Gone.git", from: "1.0.0"),\n        */',
        ]:
            with self.subTest(comment):
                text = package_swift().replace("dependencies: [", "dependencies: [\n        " + comment)
                self.assertEqual(sorted(check_lockfiles.parse_package_swift(text)),
                                 ["swift-docc-plugin"])

    def test_a_call_inside_a_string_is_not_a_dependency(self):
        for declaration in ['let example = #".package(url: "https://example.com/Bar.git", from: "2.0.0")"#',
                            'let example = ".package(url: \\"https://example.com/Bar.git\\", from: \\"2.0.0\\")"',
                            'let example = """\n.package(url: "https://example.com/Foo.git", from: "9.0.0")\n"""']:
            with self.subTest(declaration):
                text = declaration + '\n.package(url: "https://example.com/Foo.git", from: "1.0.0")'
                self.assertEqual(check_lockfiles.parse_package_swift(text),
                                 {"foo": ("https://example.com/Foo.git", "1.0.0")})

    def test_comment_markers_inside_a_string_are_not_comments(self):
        text = 'let x = "/* not a comment"\n.package(url: "https://example.com/Foo.git", from: "1.0.0") // done'
        self.assertEqual(check_lockfiles.parse_package_swift(text),
                         {"foo": ("https://example.com/Foo.git", "1.0.0")})

    def test_a_raw_string_before_a_dependency_does_not_hide_it(self):
        # `#"C:\"#` ends at `"#`; the `\"` inside it is not an escape.
        for declaration in ['let path = #"C:\\"#', 'let path = ##"a "# b"##', 'let path = #"a \\#"q"#']:
            with self.subTest(declaration):
                text = declaration + '\n.package(url: "https://example.com/Foo.git", from: "1.0.0")'
                self.assertEqual(check_lockfiles.parse_package_swift(text),
                                 {"foo": ("https://example.com/Foo.git", "1.0.0")})

    def test_a_parenthesis_inside_a_string_does_not_end_the_call(self):
        text = '.package(name: "Odd)Name", url: "https://example.com/Foo.git", from: "1.0.0")'
        self.assertEqual(check_lockfiles.parse_package_swift(text),
                         {"foo": ("https://example.com/Foo.git", "1.0.0")})

    def test_a_dependency_whose_url_is_not_a_literal_fails(self):
        # Treating it as local would leave a remote dependency unchecked.
        for call in ['.package(url: doccPluginURL, from: "1.0.0")',
                     '.package(id: "apple.swift-docc-plugin", from: "1.0.0")']:
            with self.subTest(call):
                with self.assertRaises(check_lockfiles.CheckError) as raised:
                    check_lockfiles.parse_package_swift(call)
                self.assertIn("this check cannot read the URL of", str(raised.exception))

    def test_an_unreadable_lockfile_fails_with_its_path(self):
        with self.assertRaises(check_lockfiles.CheckError) as raised:
            check_lockfiles.parse_resolved('{"version": 3}', "Some/Package.resolved")
        self.assertIn("Some/Package.resolved is not a Package.resolved file", str(raised.exception))
        self.assertIn("Run `swift package resolve` to regenerate it", str(raised.exception))

    def test_a_malformed_pin_fails_with_the_lockfile_path(self):
        pin = {"package": "SwiftDocCPlugin", "repositoryURL": DOCC, "state": {"version": "1.0.0"}}
        for broken in [{**pin, "state": None}, {**pin, "repositoryURL": None}, None]:
            with self.subTest(broken):
                text = json.dumps({"object": {"pins": [broken]}, "version": 1})
                with self.assertRaises(check_lockfiles.CheckError) as raised:
                    check_lockfiles.parse_resolved(text, "Package.resolved")
                self.assertIn("Package.resolved is not a Package.resolved file", str(raised.exception))


class MissingFileTests(Repository):
    def test_a_missing_lockfile_fails(self):
        os.remove(check_lockfiles.PACKAGE_RESOLVED)
        status, output = self.main()
        self.assertEqual(status, 1)
        [error] = self.errors(output)
        self.assertIn(check_lockfiles.PACKAGE_RESOLVED, error)


class ResolveTests(Repository):
    """--resolve, with swift and git replaced by a fake."""

    def resolve(self, failing=()):
        """Run main with --resolve. Each command whose first two words are in
        `failing` exits 1; every other command exits 0."""
        self.commands = []

        def fake_run(args, **kwargs):
            self.commands.append(list(args))
            return subprocess.CompletedProcess(args, 1 if " ".join(args[:2]) in failing else 0)

        with mock.patch.object(check_lockfiles.subprocess, "run", side_effect=fake_run):
            return self.main("--resolve")

    def test_a_fresh_lockfile_passes(self):
        status, output = self.resolve()
        self.assertEqual(status, 0)
        self.assertEqual(self.errors(output), [])
        self.assertEqual(self.commands, [
            ["swift", "package", "resolve"],
            ["git", "diff", "--exit-code", "--", "Package.resolved"],
        ])

    def test_a_lockfile_that_cannot_resolve_fails(self):
        status, output = self.resolve(failing={"swift package"})
        self.assertEqual(status, 1)
        [error] = self.errors(output)
        self.assertIn("`swift package resolve` failed, so Package.resolved cannot satisfy Package.swift", error)
        self.assertNotIn(["git", "diff", "--exit-code", "--", "Package.resolved"], self.commands)

    def test_a_stale_lockfile_fails(self):
        status, output = self.resolve(failing={"git diff"})
        self.assertEqual(status, 1)
        [error] = self.errors(output)
        self.assertIn("Package.resolved is stale: `swift package resolve` changed it", error)
        self.assertIn("run `swift package resolve` and commit Package.resolved", error)

    def test_file_errors_and_resolve_errors_are_all_reported(self):
        self.write(check_lockfiles.PACKAGE_SWIFT, package_swift(docc='from: "1.1.0"'))
        status, output = self.resolve(failing={"git diff"})
        self.assertEqual(status, 1)
        self.assertEqual(len(self.errors(output)), 2)


if __name__ == "__main__":
    unittest.main()
