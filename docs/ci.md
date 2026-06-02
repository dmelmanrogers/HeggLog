# CI Matrix

Status: complete for `REL-001`.

The CI workflow in `.github/workflows/ci.yml` is the release-quality gate for
normal pull requests and pushes to `main` or `develop`.

## Jobs

| Job | Platform | Purpose |
| --- | --- | --- |
| `docs-and-tracker` | Ubuntu | Validate documentation links, the Haskell 2010 backlog, the conformance matrix, CI workflow shape, and whitespace. |
| `build-test` | Ubuntu and macOS | Build all targets, run the full test suite, run package checks, run strict native smoke tests, and run mandatory wet tests. |

## Toolchain Matrix

| OS | GHC | Cabal | Native tools |
| --- | --- | --- | --- |
| `ubuntu-latest` | `9.10.1` | `3.12.1.0` | `clang`, `llvm`, `lli`, `llvm-as` from apt packages |
| `macos-latest` | `9.10.1` | `3.12.1.0` | Homebrew `llvm` with its `bin` directory added to `PATH` |

## Required CI Checks

Every matrix leg must pass:

```bash
cabal build all
cabal test all --test-options='--hide-successes'
cabal check
scripts/smoke-test.sh --strict-native
scripts/e2e-wet-test.sh
```

The docs/tracker job must pass:

```bash
python3 scripts/validate-doc-links.py
python3 scripts/validate-haskell2010-todo.py
python3 scripts/validate-haskell2010-conformance.py
python3 scripts/validate-ci-matrix.py
git diff --check
```

## Local Validation

The workflow is validated locally with:

```bash
python3 scripts/validate-ci-matrix.py
```

That script checks the matrix shape and all required commands. It does not
replace a GitHub-hosted CI run; it prevents silent workflow drift in local
release checks.
