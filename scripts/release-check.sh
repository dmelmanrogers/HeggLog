#!/usr/bin/env bash
set -euo pipefail

printf '== native toolchain ==\n'
scripts/check-native-toolchain.sh

printf '== lint gate ==\n'
scripts/lint.sh

printf '== cabal build all ==\n'
cabal build all

printf '== cabal test all ==\n'
cabal test all --test-options='--hide-successes'

printf '== strict native smoke tests ==\n'
scripts/smoke-test.sh --strict-native

printf '== install smoke test ==\n'
scripts/install-smoke-test.sh

printf '== examples gallery smoke test ==\n'
scripts/examples-gallery-smoke.sh

printf '== standard library packaging ==\n'
scripts/validate-standard-library-packaging.sh

printf '== runtime build integration ==\n'
scripts/runtime-build-smoke.sh

printf '== coverage report ==\n'
scripts/coverage-report.sh

printf '== benchmark suite ==\n'
scripts/benchmark.py --iterations 1

printf '== mandatory wet tests ==\n'
scripts/e2e-wet-test.sh

printf '== cabal source distribution ==\n'
cabal sdist all

printf 'release check passed\n'
