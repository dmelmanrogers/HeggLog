#!/usr/bin/env python3
"""Validate release versioning metadata."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CABAL = ROOT / "hegglog.cabal"
POLICY = ROOT / "docs" / "versioning-policy.md"
CHANGELOG = ROOT / "CHANGELOG.md"


def fail(message: str) -> None:
    print(f"versioning validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing {path.relative_to(ROOT)}")


def cabal_version() -> str:
    text = read(CABAL)
    match = re.search(r"^version:\s*([0-9]+(?:\.[0-9]+){3})\s*$", text, re.MULTILINE)
    if match is None:
        fail("hegglog.cabal must use a four-component numeric version")
    version = match.group(1)
    if any(part != "0" and part.startswith("0") for part in version.split(".")):
        fail(f"version components must not use leading zeroes: {version}")
    return version


def main() -> None:
    version = cabal_version()
    policy = read(POLICY)

    required_policy_text = [
        f"The current package version is `{version}`.",
        "MAJOR.MINOR.PATCH.REVISION",
        "Cabal/PVP-compatible",
        "scripts/release-check.sh",
        f"v{version}",
        "the same version number",
    ]
    for text in required_policy_text:
        if text not in policy:
            fail(f"versioning policy missing required text: {text}")

    changelog = read(CHANGELOG)
    heading_pattern = rf"^## {re.escape(version)} - \d{{4}}-\d{{2}}-\d{{2}}$"
    if re.search(heading_pattern, changelog, re.MULTILINE) is None:
        fail(f"CHANGELOG.md missing dated section for {version}")

    for text in ["### Added", "### Changed", "### Validation", "scripts/release-check.sh"]:
        if text not in changelog:
            fail(f"CHANGELOG.md missing required release content: {text}")

    print(f"validated versioning policy for {version}")


if __name__ == "__main__":
    main()
