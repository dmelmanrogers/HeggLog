#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/haskell-compiler-gallery.XXXXXX")"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

run_and_expect() {
  local name="$1"
  local expected="$2"
  shift 2
  printf '== %s ==\n' "$name"
  local actual
  actual="$("$@")"
  if [[ "$actual" != "$expected" ]]; then
    printf '%s expected <%s>, got <%s>\n' "$name" "$expected" "$actual" >&2
    exit 1
  fi
}

cabal build exe:haskell-compiler

run_and_expect \
  "lazy argument run" \
  "1" \
  cabal run -v0 haskell-compiler -- run examples/haskell2010/lazy-argument.hs

run_and_expect \
  "fibonacci run" \
  "21" \
  cabal run -v0 haskell-compiler -- run examples/haskell2010/fibonacci.hs

run_and_expect \
  "typeclass dictionary run" \
  "1" \
  cabal run -v0 haskell-compiler -- run examples/haskell2010/typeclass-dictionary.hs

cabal run -v0 haskell-compiler -- check examples/haskell2010/standard-library.hs
cabal run -v0 haskell-compiler -- check examples/haskell2010/io-and-show.hs

module_out="$tmpdir/modules-main"
cabal run -v0 haskell-compiler -- compile \
  examples/haskell2010/modules/Main.hs \
  --import-path examples/haskell2010/modules \
  -o "$module_out" >/dev/null
run_and_expect "multi-module native executable" "20" "$module_out"

printf 'examples gallery smoke test passed\n'
