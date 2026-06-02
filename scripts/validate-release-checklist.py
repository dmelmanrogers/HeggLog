#!/usr/bin/env python3
"""Validate the release checklist and release gate stay aligned."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHECKLIST = ROOT / "docs" / "release-checklist.md"
RELEASE_GATE = ROOT / "scripts" / "release-check.sh"


REQUIRED_COMMANDS = [
    "scripts/check-native-toolchain.sh",
    "scripts/lint.sh",
    "cabal build all",
    "cabal test all --test-options='--hide-successes'",
    "scripts/smoke-test.sh --strict-native",
    "scripts/install-smoke-test.sh",
    "scripts/examples-gallery-smoke.sh",
    "scripts/validate-standard-library-packaging.sh",
    "scripts/runtime-build-smoke.sh",
    "scripts/coverage-report.sh",
    "scripts/benchmark.py --iterations 1",
    "scripts/e2e-wet-test.sh",
    "cabal sdist all",
]

REQUIRED_ARTIFACTS = [
    ".context/coverage/summary.txt",
    ".context/coverage/html/hpc_index.html",
    ".context/coverage/hegglog-test.tix",
    ".context/benchmarks/benchmark.json",
    ".context/benchmarks/benchmark.md",
    "dist-newstyle",
]

REQUIRED_SECTIONS = [
    "## Preconditions",
    "## Required Local Commands",
    "## Artifact Checklist",
    "## Review Checklist",
    "## Failure Policy",
]


def fail(message: str) -> None:
    print(f"release checklist validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing {path.relative_to(ROOT)}")


def main() -> None:
    checklist = require_text(CHECKLIST)
    release_gate = require_text(RELEASE_GATE)

    for section in REQUIRED_SECTIONS:
        if section not in checklist:
            fail(f"checklist missing section {section}")

    for command in REQUIRED_COMMANDS:
        if command not in checklist:
            fail(f"checklist missing command {command}")
        if command == "scripts/release-check.sh":
            continue
        if command not in release_gate:
            fail(f"release gate missing command {command}")

    for artifact in REQUIRED_ARTIFACTS:
        if artifact not in checklist:
            fail(f"checklist missing artifact {artifact}")

    if "Do not release with a failing checklist item." not in checklist:
        fail("checklist must include a strict failure policy")

    print("validated release checklist")


if __name__ == "__main__":
    main()
