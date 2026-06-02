# Changelog

All notable HeggLog release changes are recorded here. The Cabal package
version in `hegglog.cabal` is the authoritative version for release tags and
changelog sections.

## 1.1.0.0 - 2026-06-02

### Added

- Release-quality CI matrix covering Ubuntu and macOS with GHC 9.10.1, Cabal
  3.12.1.0, clang, LLVM, native wet tests, coverage reporting, and benchmarks.
- clang/LLVM toolchain validation through `scripts/check-native-toolchain.sh`.
- Installation smoke testing through `scripts/install-smoke-test.sh`.
- Curated Haskell 2010 examples gallery and examples smoke testing.
- Standard-library packaging validation for the implemented Haskell 2010
  library module surface.
- Runtime build integration smoke testing for LLVM/object/executable
  intermediates and native runtime linkage.
- Formatting/linting release gate through `scripts/lint.sh`.
- Cabal/HPC coverage reporting through `scripts/coverage-report.sh`.
- Representative compiler benchmark suite through `scripts/benchmark.py`.
- Release checklist, versioning policy, and release workflow documentation.

### Changed

- Reorganized the Cabal package into a real `hegglog` library, an `app`
  executable entry point, and a test suite that depends on the library. This
  makes coverage meaningful and prevents executable/test builds from compiling
  duplicate source-module sets.
- Expanded `scripts/release-check.sh` into the authoritative release gate,
  including native toolchain validation, linting, full build/test validation,
  smoke tests, coverage, benchmarks, mandatory wet tests, and source
  distribution generation.
- Updated the Haskell 2010 tracker and release documentation to keep release
  tasks, validation scripts, and support claims aligned.

### Validation

- `cabal build lib:hegglog`
- `cabal build exe:hegglog`
- `cabal test hegglog-test --test-options='--hide-successes'`
- `cabal test hegglog-test --enable-coverage --test-options='--hide-successes'`
- `scripts/coverage-report.sh`
- `scripts/benchmark.py --iterations 1`
- `python3 scripts/validate-ci-matrix.py`
- `python3 scripts/validate-release-checklist.py`
- `python3 scripts/validate-versioning.py`
- `python3 scripts/validate-doc-links.py`
- `python3 scripts/validate-haskell2010-todo.py`
- `python3 scripts/validate-haskell2010-conformance.py`
- `cabal sdist all`
