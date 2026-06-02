#!/usr/bin/env bash
set -euo pipefail

printf '== require native toolchain ==\n'
scripts/check-native-toolchain.sh

printf '== cabal build all ==\n'
cabal build all

printf '== cabal test e2e-wet-test ==\n'
cabal test e2e-wet-test

printf '== cabal test all ==\n'
cabal test all

printf '== cabal check ==\n'
cabal check

printf '== Haskell 2010 conformance manifest/matrix validation ==\n'
python3 scripts/validate-haskell2010-conformance.py

printf '== Haskell 2010 backlog validation ==\n'
python3 scripts/validate-haskell2010-todo.py

printf '== git diff --check ==\n'
git diff --check

printf 'mandatory e2e wet tests passed\n'
