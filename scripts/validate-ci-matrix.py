#!/usr/bin/env python3
"""Validate the CI workflow structure expected by release-quality tasks."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "ci.yml"


REQUIRED_TEXT = [
    "docs-and-tracker:",
    "build-test:",
    "coverage:",
    "benchmarks:",
    "fail-fast: false",
    "ubuntu-latest",
    "macos-latest",
    'ghc: "9.10.1"',
    'cabal: "3.12.1.0"',
    "sudo apt-get update && sudo apt-get install -y clang llvm",
    "brew install llvm || brew upgrade llvm",
    "scripts/lint.sh",
    "cabal build all",
    "cabal test all --test-options='--hide-successes'",
    "cabal check",
    "scripts/smoke-test.sh --strict-native",
    "scripts/install-smoke-test.sh",
    "scripts/examples-gallery-smoke.sh",
    "scripts/validate-standard-library-packaging.sh",
    "scripts/runtime-build-smoke.sh",
    "scripts/e2e-wet-test.sh",
    "scripts/check-native-toolchain.sh",
    "scripts/coverage-report.sh",
    "scripts/benchmark.py --iterations 1",
]


def fail(message: str) -> None:
    print(f"CI matrix validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    try:
        text = WORKFLOW.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail("missing .github/workflows/ci.yml")

    for required in REQUIRED_TEXT:
        if required not in text:
            fail(f"workflow missing required entry: {required}")

    if not re.search(r"strategy:\n(?:  .+\n)*      matrix:", text):
        fail("build-test job must define a strategy matrix")
    if "permissions:\n  contents: read" not in text:
        fail("workflow must use read-only contents permission")
    if "concurrency:" not in text or "cancel-in-progress: true" not in text:
        fail("workflow must cancel stale runs")
    if not re.search(r"coverage:\n(?:  .+\n)*    needs: build-test", text):
        fail("coverage job must depend on the full build-test matrix")
    if not re.search(r"benchmarks:\n(?:  .+\n)*    needs: build-test", text):
        fail("benchmarks job must depend on the full build-test matrix")

    print("validated CI workflow matrix")


if __name__ == "__main__":
    main()
