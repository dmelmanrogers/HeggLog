# Coverage Reporting

HeggLog coverage reporting uses Cabal's HPC integration against the internal
`hegglog` library and the full `hegglog-test` suite. The coverage path is a
release validation tool, not a substitute for conformance, native wet tests, or
the release gate.

## Command

Run:

```bash
scripts/coverage-report.sh
```

The script runs:

```bash
cabal test hegglog-test --enable-coverage --test-options='--hide-successes'
```

It then verifies that Cabal produced both:

- `hpc_index.html`, the HTML coverage report
- `hegglog-test.tix`, the raw HPC execution trace

The script copies those artifacts into `.context/coverage`:

- `.context/coverage/html/hpc_index.html`
- `.context/coverage/hegglog-test.tix`
- `.context/coverage/summary.txt`

Pass a custom output directory as the first argument when needed:

```bash
scripts/coverage-report.sh /tmp/hegglog-coverage
```

## Package Shape

Coverage requires the compiler implementation to be built as a Cabal library.
The package is therefore structured as:

- `src`: the `hegglog` library modules
- `app`: the `hegglog` executable entry point
- `test`: the `hegglog-test` test suite, depending on the library

This keeps coverage focused on compiler modules that users and tests exercise,
and prevents executable/test builds from compiling ad hoc duplicate source
module sets.

## CI and Release Use

CI runs coverage on Ubuntu in a dedicated job. The full release gate also runs
coverage reporting so the generated report and `.tix` file are verified before a
release.

Coverage percentages are recorded for visibility, but this project does not
currently enforce a numeric coverage floor. The authoritative quality gates are:

- the Haskell 2010 conformance suites and manifests
- the full Cabal test suite
- mandatory native wet tests
- release smoke tests for installation, examples, standard-library packaging,
  and runtime build integration
