#!/usr/bin/env python3
"""Validate relative Markdown links in README and docs files."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOC_ROOTS = [ROOT / "README.md", ROOT / "CHANGELOG.md", ROOT / "docs"]
LINK_RE = re.compile(r"(?<!!)\[[^\]\n]+\]\(([^)\n]+)\)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$")
ALLOWED_MISSING_ANCHORS = {"top"}


def fail(message: str) -> None:
    print(f"doc link validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def markdown_files() -> list[Path]:
    files: list[Path] = []
    for root in DOC_ROOTS:
        if root.is_file() and root.exists():
            files.append(root)
        elif root.is_dir():
            files.extend(sorted(root.glob("*.md")))
    return sorted(set(files))


def strip_code_blocks(text: str) -> str:
    lines: list[str] = []
    in_fence = False
    for line in text.splitlines():
        if line.startswith("```"):
            in_fence = not in_fence
            lines.append("")
        elif in_fence:
            lines.append("")
        else:
            lines.append(line)
    return "\n".join(lines)


def slug_heading(raw: str) -> str:
    text = re.sub(r"<[^>]+>", "", raw)
    text = re.sub(r"`([^`]+)`", r"\1", text)
    text = text.strip().lower()
    text = re.sub(r"[^a-z0-9 _-]", "", text)
    text = re.sub(r"\s+", "-", text)
    text = re.sub(r"-+", "-", text)
    return text.strip("-")


def anchors_for(path: Path) -> set[str]:
    anchors: set[str] = set()
    text = path.read_text(encoding="utf-8")
    for line in text.splitlines():
        match = HEADING_RE.match(line)
        if match is not None:
            slug = slug_heading(match.group(2))
            if slug:
                anchors.add(slug)
    return anchors


def is_external(target: str) -> bool:
    lowered = target.lower()
    return (
        lowered.startswith("http://")
        or lowered.startswith("https://")
        or lowered.startswith("mailto:")
        or lowered.startswith("tel:")
    )


def split_target(target: str) -> tuple[str, str | None]:
    path_part, separator, anchor = target.partition("#")
    return path_part, anchor if separator else None


def validate_file(path: Path, anchor_cache: dict[Path, set[str]]) -> None:
    text = strip_code_blocks(path.read_text(encoding="utf-8"))
    for match in LINK_RE.finditer(text):
        target = match.group(1).strip()
        if not target or is_external(target):
            continue
        path_part, anchor = split_target(target)
        if path_part:
            target_path = (path.parent / path_part).resolve()
            if not target_path.exists():
                fail(
                    f"{path.relative_to(ROOT)} links to missing file "
                    f"{target}"
                )
            if target_path.is_dir():
                fail(
                    f"{path.relative_to(ROOT)} links to directory {target}"
                )
        else:
            target_path = path.resolve()

        if anchor:
            if target_path.suffix.lower() != ".md":
                fail(
                    f"{path.relative_to(ROOT)} links to anchor in non-Markdown "
                    f"file {target}"
                )
            normalized_anchor = anchor.strip().lower()
            if normalized_anchor not in anchor_cache.setdefault(
                target_path,
                anchors_for(target_path),
            ) and normalized_anchor not in ALLOWED_MISSING_ANCHORS:
                fail(
                    f"{path.relative_to(ROOT)} links to missing anchor "
                    f"#{anchor} in {target_path.relative_to(ROOT)}"
                )


def main() -> None:
    files = markdown_files()
    if not files:
        fail("no Markdown files found")
    anchor_cache: dict[Path, set[str]] = {}
    for path in files:
        validate_file(path, anchor_cache)
    print(f"validated Markdown links in {len(files)} files")


if __name__ == "__main__":
    main()
