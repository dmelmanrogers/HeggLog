#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/hegglog-install.XXXXXX")"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

bindir="$tmpdir/bin"
mkdir -p "$bindir"

printf '== native toolchain ==\n'
scripts/check-native-toolchain.sh

printf '== cabal install exe:hegglog ==\n'
cabal install exe:hegglog \
  --installdir="$bindir" \
  --overwrite-policy=always \
  --install-method=copy

hegglog="$bindir/hegglog"
if [[ ! -x "$hegglog" ]]; then
  printf 'installed hegglog executable not found at %s\n' "$hegglog" >&2
  exit 1
fi

printf '== installed binary help ==\n'
"$hegglog" --help >/dev/null

printf '== installed binary check ==\n'
"$hegglog" check test/e2e/programs/haskell2010/lazy-argument.hs

printf '== installed binary compile/run ==\n'
out="$tmpdir/lazy-argument"
"$hegglog" compile test/e2e/programs/haskell2010/lazy-argument.hs -o "$out"
actual="$("$out")"
if [[ "$actual" != "1" ]]; then
  printf 'expected installed compiled example to print 1, got %s\n' "$actual" >&2
  exit 1
fi

printf 'install smoke test passed\n'
