#!/usr/bin/env bash
set -euo pipefail

printf '== shell script syntax and executable bits ==\n'
for script in scripts/*.sh; do
  bash -n "$script"
  if [[ ! -x "$script" ]]; then
    printf 'shell script is not executable: %s\n' "$script" >&2
    exit 1
  fi
done

printf '== Python script syntax ==\n'
python3 -m py_compile scripts/*.py

printf '== documentation links ==\n'
python3 scripts/validate-doc-links.py

printf '== Haskell 2010 backlog ==\n'
python3 scripts/validate-haskell2010-todo.py

printf '== Haskell 2010 conformance matrix ==\n'
python3 scripts/validate-haskell2010-conformance.py

printf '== CI workflow shape ==\n'
python3 scripts/validate-ci-matrix.py

printf '== release checklist ==\n'
python3 scripts/validate-release-checklist.py

printf '== versioning policy ==\n'
python3 scripts/validate-versioning.py

printf '== examples gallery ==\n'
python3 scripts/validate-examples-gallery.py

printf '== whitespace ==\n'
git diff --check

printf '== cabal check ==\n'
cabal check

printf '== cabal build all with package warnings ==\n'
cabal build all

printf 'lint checks passed\n'
