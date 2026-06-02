# Benchmark Suite

The benchmark suite measures representative HeggLog compiler workflows while
also validating their observable behavior. It is intended for release tracking
and regression investigation, not as a conformance substitute.

## Command

Run:

```bash
scripts/benchmark.py
```

The default run executes one measured iteration per benchmark case and writes:

- `.context/benchmarks/benchmark.json`
- `.context/benchmarks/benchmark.md`

Run more iterations for local comparison work:

```bash
scripts/benchmark.py --iterations 5
```

Write results somewhere else:

```bash
scripts/benchmark.py --output-dir /tmp/hegglog-benchmarks
```

## Workloads

The suite builds `exe:hegglog` once, resolves the executable with
`cabal list-bin`, and runs these fixed workloads:

- `check-fibonacci`: typecheck/validate a recursive Haskell 2010 example
- `emit-core-typeclass`: emit original and optimized typed Core for a
  dictionary-heavy example
- `run-fibonacci`: compile and run a recursive Haskell 2010 example through
  the native execution path
- `compile-lazy-native`: produce a native executable for a laziness fixture
- `execute-compiled-lazy`: execute the native artifact from the compile
  benchmark
- `report-standard-library`: produce a diagnostic report for a
  standard-library import example
- `check-module-graph`: validate a multi-module example through import search
  paths

Each benchmark checks exit status, stdout, and stderr expectations. A benchmark
run fails immediately if the compiler output is wrong.

## Release Use

CI runs the benchmark suite on Ubuntu in a dedicated job. The release gate also
runs the suite after coverage reporting. The project does not enforce a numeric
performance threshold yet because the benchmark suite is new and baseline
history needs to be collected across several releases. The benchmark artifacts
are still mandatory: missing artifacts or incorrect command behavior fail the
suite.
