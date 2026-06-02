#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

output_dir="${1:-.context/coverage}"

rm -rf "$output_dir"
mkdir -p "$output_dir/html"

cabal test hegglog-test --enable-coverage --test-options='--hide-successes'

html_index="$(
  find dist-newstyle -path '*hegglog-test/hpc/vanilla/html/hpc_index.html' -print \
    | sort \
    | tail -n 1
)"
tix_file="$(
  find dist-newstyle -path '*hegglog-test/hpc/vanilla/tix/hegglog-test.tix' -print \
    | sort \
    | tail -n 1
)"

if [[ -z "$html_index" || ! -f "$html_index" ]]; then
  printf 'coverage report failed: missing Cabal HPC HTML index\n' >&2
  exit 1
fi

if [[ -z "$tix_file" || ! -f "$tix_file" ]]; then
  printf 'coverage report failed: missing Cabal HPC .tix file\n' >&2
  exit 1
fi

cp -R "$(dirname "$html_index")"/. "$output_dir/html/"
cp "$tix_file" "$output_dir/hegglog-test.tix"

python3 - "$output_dir/html/hpc_index.html" "$output_dir/summary.txt" <<'PY'
from __future__ import annotations

import re
import sys
from html import unescape
from pathlib import Path


html_path = Path(sys.argv[1])
summary_path = Path(sys.argv[2])

html = html_path.read_text(encoding="utf-8")
marker = "Program Coverage Total"
if marker not in html:
    print("coverage report failed: missing Program Coverage Total row", file=sys.stderr)
    raise SystemExit(1)

total_section = html[html.index(marker) :]
cells = re.findall(r"<td[^>]*>(.*?)</td>", total_section, re.DOTALL)
values = []
for cell in cells:
    text = re.sub(r"<[^>]+>", "", cell)
    text = unescape(text).replace("\xa0", " ").strip()
    if re.fullmatch(r"\d+%", text) or re.fullmatch(r"\d+/\d+", text):
        values.append(text)

if len(values) != 6:
    print(
        f"coverage report failed: expected 6 total values, found {len(values)}",
        file=sys.stderr,
    )
    raise SystemExit(1)

labels = ["Top-level definitions", "Alternatives", "Expressions"]
lines = ["# HeggLog Coverage Summary", ""]
for label, percent, count in zip(labels, values[0::2], values[1::2]):
    lines.append(f"- {label}: {percent} ({count})")
lines.extend(
    [
        "",
        f"- HTML index: {html_path}",
        f"- TIX file: {summary_path.parent / 'hegglog-test.tix'}",
        "",
    ]
)

summary_path.write_text("\n".join(lines), encoding="utf-8")
print(summary_path.read_text(encoding="utf-8"), end="")
PY

printf 'coverage artifacts written to %s\n' "$output_dir"
