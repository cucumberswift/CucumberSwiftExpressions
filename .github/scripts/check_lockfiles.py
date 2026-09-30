#!/usr/bin/env python3
"""Check that Package.swift agrees with Package.resolved.

This fails when:

  1. a lower bound in Package.swift is not the version Package.resolved pins;
  2. with --resolve, Package.resolved is stale or does not satisfy Package.swift.

Run from the repository root:

  python3 .github/scripts/check_lockfiles.py            # check 1
  python3 .github/scripts/check_lockfiles.py --resolve  # and check 2 (needs swift and git)

Only the standard library is used.
"""
import json
import re
import subprocess
import sys

PACKAGE_SWIFT = "Package.swift"
PACKAGE_RESOLVED = "Package.resolved"

# How to fix it, for the error messages.
FIX = f"Edit {PACKAGE_SWIFT}, then run `swift package resolve` and commit {PACKAGE_RESOLVED}."

# The version argument of a SwiftPM requirement. `from:` and the
# `.upToNext...(from:)` forms have a lower bound; so do `exact:` and a range.
REQUIREMENT = re.compile(
    r'(?:\bfrom|\bexact)\s*:\s*"([^"]+)"'
    r'|\.(?:upToNextMajor|upToNextMinor)\s*\(\s*from\s*:\s*"([^"]+)"'
    r'|\.exact\s*\(\s*"([^"]+)"'
    r'|"([^"]+)"\s*\.\.[.<]')
# The start of a string literal: a `"`, after any `#`s of a raw string's delimiter.
STRING_START = re.compile(r'#*"')
LOCAL = re.compile(r'\bpath\s*:\s*"')
URL = re.compile(r'\burl\s*:\s*"([^"]+)"')
class CheckError(Exception):
    """A file this check cannot read."""


def identity(url):
    """SwiftPM's package identity: the last path component, lowercased, without .git."""
    name = url.rstrip("/").rsplit("/", 1)[-1].lower()
    return name[:-4] if name.endswith(".git") else name


def same_repository(first, second):
    """Whether two URLs name the same repository, ignoring case, a trailing / and .git."""
    def normalized(url):
        url = url.lower().rstrip("/")
        return url[:-4] if url.endswith(".git") else url
    return normalized(first) == normalized(second)


def string_end(text, index):
    """The index just after the string literal that starts at `index`: a `"`, or `#`s
    and a `"` for a raw string such as `#"C:\"#`, which only `"#` ends. Handles
    escapes (`\\` followed by as many `#`s) and multiline (triple-quoted) strings; an
    unterminated string runs to the end."""
    hashes = STRING_START.match(text, index).end() - 1 - index
    index += hashes
    quote = '"' * 3 if text.startswith('"' * 3, index) else '"'
    close, escape = quote + "#" * hashes, "\\" + "#" * hashes
    index += len(quote)
    while index < len(text) and not text.startswith(close, index):
        index += len(escape) + 1 if text.startswith(escape, index) else 1
    return min(index + len(close), len(text))


def block_comment_end(text, index):
    """The index just after the `/* */` comment that starts at `index`. They nest."""
    depth, index = 1, index + 2
    while depth and index < len(text):
        pair = text[index:index + 2]
        depth += {"/*": 1, "*/": -1}.get(pair, 0)
        index += 2 if pair in ("/*", "*/") else 1
    return index


def strip_comments(text):
    """Swift source without its comments: `//` to the end of the line, and `/* */`,
    which nest. String literals are kept as they are, so `//` in a URL survives."""
    out, index = [], 0
    while index < len(text):
        pair = text[index:index + 2]
        if pair == "/*":
            index = block_comment_end(text, index)
        elif pair == "//":
            newline = text.find("\n", index)
            index = len(text) if newline < 0 else newline
        else:
            end = string_end(text, index) if STRING_START.match(text, index) else index + 1
            out.append(text[index:end])
            index = end
    return "".join(out)


def call_end(text, index):
    """The index of the `)` closing a call whose arguments start at `index`, or None.
    Parentheses inside a string literal do not count."""
    depth = 1
    while index < len(text):
        if STRING_START.match(text, index):
            index = string_end(text, index)
            continue
        depth += {"(": 1, ")": -1}.get(text[index], 0)
        if depth == 0:
            return index
        index += 1
    return None


def package_calls(text):
    """Yield the argument text of each `.package(...)` call."""
    for match in re.finditer(r"\.package\s*\(", text):
        end = call_end(text, match.end())
        if end is not None:
            yield text[match.end():end]


def parse_package_swift(text):
    """Return {identity: (url, lower bound)} for each remote dependency."""
    dependencies = {}
    for arguments in package_calls(strip_comments(text)):
        url = URL.search(arguments)
        if not url and LOCAL.search(arguments):
            continue  # a local package has no lockfile pin
        if not url:
            # Fail rather than skip: a remote dependency whose URL is not a string
            # literal (a constant, a registry `id:`) would otherwise go unchecked.
            raise CheckError(f"{PACKAGE_SWIFT}: this check cannot read the URL of "
                             f"`.package({' '.join(arguments.split())})`. Write the URL as a "
                             f"string literal, `url: \"https://...\"`.")
        requirement = REQUIREMENT.search(arguments)
        if not requirement:
            raise CheckError(f"{PACKAGE_SWIFT}: {url.group(1)} has no version requirement this "
                             f"check can read. Use a version range such as `from: \"1.2.0\"`.")
        bound = next(group for group in requirement.groups() if group)
        dependencies[identity(url.group(1))] = (url.group(1), bound)
    return dependencies


def parse_resolved(text, path):
    """Return {identity: {url, version, revision}} for each pin, from any lockfile format."""
    try:
        data = json.loads(text)
        version = data["version"]
        pins = data["object"]["pins"] if version == 1 else data["pins"]
        result = {}
        for pin in pins:
            url = pin["repositoryURL"] if version == 1 else pin["location"]
            state = pin["state"]
            result[identity(url)] = {"url": url, "version": state.get("version"),
                                     "revision": state.get("revision")}
        return result
    except (ValueError, KeyError, TypeError) as error:
        raise CheckError(f"{path} is not a Package.resolved file this check can read ({error}).")


def check_bounds(dependencies, pins):
    """Errors for each direct dependency whose lower bound is not its locked version."""
    errors = []
    for name, (url, bound) in sorted(dependencies.items()):
        pin = pins.get(name)
        if pin is None:
            errors.append(f"{PACKAGE_RESOLVED} has no pin for {url}, which {PACKAGE_SWIFT} "
                          f"requires. {FIX}")
        elif not same_repository(pin["url"], url):
            errors.append(f"{PACKAGE_SWIFT} requires {url}, but {PACKAGE_RESOLVED} pins "
                          f"{pin['url']}, a different repository with the same package "
                          f"identity. {FIX}")
        elif pin["version"] is None:
            errors.append(f"{PACKAGE_RESOLVED} pins {url} to a branch or revision, not a "
                          f"version. {FIX}")
        elif pin["version"] != bound:
            errors.append(f"{PACKAGE_SWIFT} requires {url} from {bound}, but {PACKAGE_RESOLVED} "
                          f"pins {pin['version']}. Set the lower bound in {PACKAGE_SWIFT} to "
                          f"{pin['version']}, the version CI builds against. {FIX}")
    return errors


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def check_files():
    """Check 1, on the files in the working directory."""
    return check_bounds(parse_package_swift(read(PACKAGE_SWIFT)),
                        parse_resolved(read(PACKAGE_RESOLVED), PACKAGE_RESOLVED))


def run(*args):
    """Run a command, streaming its output to the log. Return its exit status."""
    print(f"$ {' '.join(args)}", flush=True)
    return subprocess.run(args).returncode


def check_resolve():
    """Check 2: resolve Package.resolved against Package.swift, and fail if it changes."""
    if run("swift", "package", "resolve") != 0:
        return [f"`swift package resolve` failed, so {PACKAGE_RESOLVED} cannot satisfy "
                f"{PACKAGE_SWIFT}. {FIX}"]
    if run("git", "diff", "--exit-code", "--", PACKAGE_RESOLVED) != 0:
        return [f"{PACKAGE_RESOLVED} is stale: `swift package resolve` changed it (diff "
                f"above). {FIX}"]
    return []


def main(argv):
    try:
        errors = check_files()
    except (CheckError, OSError) as error:
        errors = [str(error)]
    if "--resolve" in argv:
        errors += check_resolve()
    for error in errors:
        print(f"::error::{error}")
    if errors:
        return 1
    print(f"{PACKAGE_SWIFT} agrees with {PACKAGE_RESOLVED}.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
