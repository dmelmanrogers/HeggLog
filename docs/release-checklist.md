# Release Checklist

This checklist is the human-facing release ledger for HeggLog. It complements
`scripts/release-check.sh`; it does not replace or weaken that gate.

## Preconditions

- The release branch is based on the intended `main` commit.
- The working tree contains only intentional release changes.
- The Haskell 2010 tracker, conformance matrix, README, and documentation index
  describe the support claim made by the release.
- Unsupported behavior remains represented by explicit conformance fixtures or
  documented deviations.
- The release version, release notes, and changelog entry agree.

## Required Local Commands

Run these from the repository root and keep their output as release evidence:

```bash
scripts/check-native-toolchain.sh
scripts/lint.sh
cabal build all
cabal test all --test-options='--hide-successes'
scripts/smoke-test.sh --strict-native
scripts/install-smoke-test.sh
scripts/examples-gallery-smoke.sh
scripts/validate-standard-library-packaging.sh
scripts/runtime-build-smoke.sh
scripts/coverage-report.sh
scripts/benchmark.py --iterations 1
scripts/e2e-wet-test.sh
cabal sdist all
scripts/release-check.sh
```

`scripts/release-check.sh` is the authoritative single-command gate. The
individual commands above are listed so failures can be isolated and rerun
without ambiguity during release preparation.

## Artifact Checklist

- `.context/coverage/summary.txt` exists and lists program coverage totals.
- `.context/coverage/html/hpc_index.html` exists.
- `.context/coverage/hegglog-test.tix` exists.
- `.context/benchmarks/benchmark.json` exists.
- `.context/benchmarks/benchmark.md` exists.
- Cabal source distribution artifacts are generated under `dist-newstyle`.
- No generated `.context` or `dist-newstyle` artifacts are committed.

## Review Checklist

- Confirm `docs/haskell2010-todo.md` and `docs/haskell2010-todo.json` agree.
- Confirm `python3 scripts/validate-haskell2010-todo.py` passes.
- Confirm `python3 scripts/validate-haskell2010-conformance.py` passes.
- Confirm `python3 scripts/validate-versioning.py` passes.
- Confirm `CHANGELOG.md` has a dated section matching the Cabal version.
- Confirm the CI workflow includes docs/tracker, OS matrix, coverage, and
  benchmark jobs.
- Confirm installation, LLVM toolchain, runtime build, standard-library
  packaging, coverage, and benchmark docs are linked from `docs/index.md`.
- Confirm release notes do not claim support beyond the validated Haskell 2010
  conformance matrix and tracker.

## Failure Policy

- Do not release with a failing checklist item.
- Do not mark a release task complete because a failure is inconvenient.
- Do not remove or weaken a conformance fixture to pass the gate.
- Do not tag a release from uncommitted source changes.
