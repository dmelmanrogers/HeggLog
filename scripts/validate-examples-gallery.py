#!/usr/bin/env python3
"""Validate the examples gallery document and curated example files."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GALLERY = ROOT / "docs" / "examples-gallery.md"

REQUIRED_EXAMPLES = {
    "examples/haskell2010/lazy-argument.hs",
    "examples/haskell2010/fibonacci.hs",
    "examples/haskell2010/io-and-show.hs",
    "examples/haskell2010/typeclass-dictionary.hs",
    "examples/haskell2010/standard-library.hs",
    "examples/haskell2010/modules/Main.hs",
    "examples/haskell2010/modules/Lib.hs",
}

PATH_RE = re.compile(r"`((?:examples|test)/[^`]+)`")


def fail(message: str) -> None:
    print(f"examples gallery validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    try:
        text = GALLERY.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail("missing docs/examples-gallery.md")

    referenced = set(PATH_RE.findall(text))
    missing_required = sorted(REQUIRED_EXAMPLES - referenced)
    if missing_required:
        fail("gallery is missing required examples: " + ", ".join(missing_required))

    for rel_path in referenced:
        if not (ROOT / rel_path).exists():
            fail(f"gallery references missing file {rel_path}")

    required_commands = [
        "hegglog check",
        "hegglog run",
        "hegglog compile",
        "--import-path",
        "scripts/examples-gallery-smoke.sh",
    ]
    for command in required_commands:
        if command not in text:
            fail(f"gallery is missing command reference {command}")

    print(f"validated examples gallery with {len(referenced)} referenced files")


if __name__ == "__main__":
    main()
