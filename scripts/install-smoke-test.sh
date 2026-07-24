#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/haskell-compiler-install.XXXXXX")"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

bindir="$tmpdir/bin"
mkdir -p "$bindir"

printf '== native toolchain ==\n'
scripts/check-native-toolchain.sh

printf '== cabal install exe:haskell-compiler ==\n'
cabal install exe:haskell-compiler \
  --installdir="$bindir" \
  --overwrite-policy=always \
  --install-method=copy

haskell-compiler="$bindir/haskell-compiler"
if [[ ! -x "$haskell-compiler" ]]; then
  printf 'installed haskell-compiler executable not found at %s\n' "$haskell-compiler" >&2
  exit 1
fi

printf '== installed binary help ==\n'
"$haskell-compiler" --help >/dev/null

printf '== installed binary check ==\n'
"$haskell-compiler" check test/e2e/programs/haskell2010/lazy-argument.hs

printf '== installed binary compile/run ==\n'
out="$tmpdir/lazy-argument"
"$haskell-compiler" compile test/e2e/programs/haskell2010/lazy-argument.hs -o "$out"
actual="$("$out")"
if [[ "$actual" != "1" ]]; then
  printf 'expected installed compiled example to print 1, got %s\n' "$actual" >&2
  exit 1
fi

printf 'install smoke test passed\n'
