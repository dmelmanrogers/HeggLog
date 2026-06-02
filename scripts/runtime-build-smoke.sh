#!/usr/bin/env bash
set -euo pipefail

workdir=".context/runtime-build-integration"
source_file="$workdir/runtime-build-main.hs"
output_file="$workdir/runtime-build-main"
intermediate_dir=".context/hegglog/intermediates"
llvm_file="$intermediate_dir/runtime-build-main.ll"
object_file="$intermediate_dir/runtime-build-main.o"

mkdir -p "$workdir" "$intermediate_dir"
rm -f "$source_file" "$output_file" "$llvm_file" "$object_file"

cat >"$source_file" <<'EOF'
module Main where

main = if const True (div 1 0) then 3 else 0
EOF

printf '== runtime build toolchain ==\n'
scripts/check-native-toolchain.sh

printf '== compile with kept runtime intermediates ==\n'
cabal run -v0 hegglog -- compile "$source_file" --keep-intermediates -o "$output_file"

if [[ ! -x "$output_file" ]]; then
  printf 'native executable was not created at %s\n' "$output_file" >&2
  exit 1
fi
if [[ ! -s "$llvm_file" ]]; then
  printf 'LLVM intermediate was not created at %s\n' "$llvm_file" >&2
  exit 1
fi
if [[ ! -s "$object_file" ]]; then
  printf 'object intermediate was not created at %s\n' "$object_file" >&2
  exit 1
fi
if ! grep -q "lazy enter/apply runtime" "$llvm_file"; then
  printf 'LLVM intermediate does not include the lazy runtime marker\n' >&2
  exit 1
fi
if ! grep -q "@hegglog_hs_argc" "$llvm_file"; then
  printf 'LLVM intermediate does not include process/runtime globals\n' >&2
  exit 1
fi

actual="$("$output_file")"
if [[ "$actual" != "3" ]]; then
  printf 'expected runtime build executable to print 3, got %s\n' "$actual" >&2
  exit 1
fi

printf 'runtime build integration smoke test passed\n'
