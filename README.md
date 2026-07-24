# Haskell Compiler

Haskell Compiler is a Haskell 2010 native compiler project implemented in Haskell. The
repository now contains two related compiler paths:

- the original strict `.hg` compiler substrate, still kept as a regression
  baseline for parsing, typechecking, ANF, Egglog-inspired optimization, LLVM IR
  generation, native executable output, and black-box wet tests
- the active Haskell 2010 `.hs` compiler path, which parses, renames,
  typechecks, lowers through typed Core and STG-like lazy IR, applies safe Core
  optimization, emits LLVM, links with `clang`, and runs native executables for
  the documented executable subset

The project goal remains Haskell 2010 source to native executables through LLVM
and clang. Current support is substantial but still scoped by the repository's
documented conformance matrix and executable-subset tests; it does not claim GHC
compatibility, package database compatibility, or arbitrary Hackage package
support.

## Current Status

Implemented today for the current `.hg` compiler-supported subset:

- parsing, typechecking, and report/interpreter mode
- ANF and resolved ANF
- Egglog optimization for supported strict ANF fragments
- checked signed `Int64` runtime semantics
- top-level first-order functions, lambda lifting, and local closure conversion
- LLVM IR generation
- native executable output through `clang`
- mandatory black-box wet tests that compile real `.hg` files, execute native
  artifacts, verify stdout/stderr/exit codes, compare report-mode
  `Result: <value>` output, and compile selected emitted LLVM through `clang`

Implemented today for the Haskell 2010 compiler path:

- layout-aware Haskell 2010 frontend
- renamer, module graph loading, import search paths, imports, exports,
  qualified aliases, implicit/explicit Prelude behavior, instance movement,
  and whole-program source-graph compilation for the executable subset
- typed Core IR, validator, and utilities
- Hindley-Milner typechecker, kind checking, class dictionaries, deriving,
  standard-library module interfaces, and source-to-Core desugaring for the
  documented executable subset
- Core-0 reference evaluator for validated typed Core
- STG-like lazy IR and in-process runtime evaluator
- Core-to-STG lowering for the executable subset
- native executable output for the executable subset through a boxed lazy
  STG LLVM runtime
- Egglog Core optimization for safe typed Core fragments, including arithmetic
  and Bool rewrites, known-constructor rewrites, demand/strictness facts, and
  known dictionary simplification with Core/STG/native oracle tests and
  `--no-egglog` comparison coverage
- custom ADTs, records, newtypes, list/tuple and Prelude data constructors,
  recursion, user-defined dictionary-passed classes, Report-shaped
  `Show`/`Read` surfaces for supported values, deriving for supported
  `Eq`/`Ord`/`Show`/`Read`/`Enum`/`Bounded` declarations, overloaded integer
  literals/defaulting, broad Prelude/library imports, `main :: IO ()`,
  `putStrLn`, `getLine`, `print`, `System.IO`, `System.Environment`,
  `System.Exit`, and multi-file modules through search paths
- Haskell 2010 FFI import/export lowering for the supported `ccall` ABI slice,
  including scalar/floating/pointer marshalling, link metadata, wrapper
  callbacks, foreign exports, `StablePtr`, `ForeignPtr`, finalizers, and
  Foreign library helpers covered by native fixtures
- a mandatory Haskell 2010 conformance baseline with a JSON manifest, 158
  conformance cases, exact native stdout checks, runtime-error checks,
  compile-error checks, and explicit unsupported-feature cases

Roadmap/tracker state:

- the numbered Haskell 2010 engineering tracker currently validates as complete
  at 409/409 tasks
- unsupported behavior is tracked by explicit conformance fixtures or
  documentation rather than silent omissions
- new work should be added as new tracker-numbered tasks before implementation,
  especially when expanding the conformance matrix beyond the current native
  executable subset

The current compiler passes the documented Haskell 2010 conformance fixtures in
the repository. Unsupported behavior is represented as explicit conformance
fixtures rather than omitted from testing. The authoritative status is the
numbered tracker in `docs/haskell2010-todo.md`.

## Quickstart

Build and test:

```bash
cabal build all
cabal test all
```

Install and smoke-test the executable:

```bash
scripts/install-smoke-test.sh
```

Run the curated examples gallery smoke test:

```bash
scripts/examples-gallery-smoke.sh
```

Run the runtime build integration smoke test:

```bash
scripts/runtime-build-smoke.sh
```

Run the lint gate:

```bash
scripts/lint.sh
```

Run the coverage report:

```bash
scripts/coverage-report.sh
```

Run the benchmark suite:

```bash
scripts/benchmark.py
```

Run the mandatory end-to-end wet-test path:

```bash
scripts/e2e-wet-test.sh
```

Run the full release gate:

```bash
scripts/release-check.sh
```

Run only the Haskell 2010 conformance baseline:

```bash
cabal test haskell2010-conformance-test --test-options='--hide-successes'
```

Validate the Haskell 2010 engineering backlog:

```bash
python3 scripts/validate-haskell2010-todo.py
```

Validate the native toolchain required by release-quality native tests:

```bash
scripts/check-native-toolchain.sh
```

Run current `.hg` report/interpreter mode:

```bash
cabal run haskell-compiler -- examples/test.hg
cabal run haskell-compiler -- report examples/test.hg
```

Emit a Haskell 2010 diagnostic/status report without native code generation:

```bash
cabal run haskell-compiler -- report test/e2e/programs/haskell2010/lazy-argument.hs
cabal run haskell-compiler -- report test/e2e/programs/haskell2010/lazy-argument.hs --no-egglog
```

The top-level CLI accepts `haskell-compiler --help`, `haskell-compiler check --help`,
`haskell-compiler emit-core --help`, `haskell-compiler emit-stg --help`, `haskell-compiler run --help`,
`haskell-compiler compile --help`, and `haskell-compiler report --help`. Help is printed to
stdout and is locked by exact public golden tests; malformed command lines
print a scoped diagnostic and the relevant usage text to stderr.

Check a supported source file without native code generation:

```bash
cabal run haskell-compiler -- check test/e2e/programs/haskell2010/lazy-argument.hs
```

Dump stable intermediate IR while preserving command stdout:

```bash
cabal run haskell-compiler -- check test/e2e/programs/haskell2010/lazy-argument.hs --dump-core --dump-stg
cabal run haskell-compiler -- compile test/e2e/programs/haskell2010/lazy-argument.hs --emit-llvm --dump-optimized-core
cabal run haskell-compiler -- run test/e2e/programs/haskell2010/lazy-argument.hs --dump-stg
```

Preserve generated intermediates for debugging:

```bash
cabal run haskell-compiler -- compile test/e2e/programs/haskell2010/lazy-argument.hs --emit-llvm --keep-intermediates
cabal run haskell-compiler -- run test/e2e/programs/haskell2010/lazy-argument.hs --keep-intermediates
ls .context/haskell-compiler/intermediates
```

Emit validated typed Haskell 2010 Core without LLVM or native code generation:

```bash
cabal run haskell-compiler -- emit-core test/e2e/programs/haskell2010/lazy-argument.hs --original --no-egglog
cabal run haskell-compiler -- emit-core test/e2e/programs/haskell2010/lazy-argument.hs --both -o /tmp/haskell-compiler.core
```

Emit validated Haskell 2010 STG without LLVM or native code generation:

```bash
cabal run haskell-compiler -- emit-stg test/e2e/programs/haskell2010/lazy-argument.hs --no-egglog
cabal run haskell-compiler -- emit-stg test/e2e/programs/haskell2010/lazy-argument.hs -o /tmp/haskell-compiler.stg
```

Compile and run a supported source file through a temporary native executable:

```bash
cabal run haskell-compiler -- run test/e2e/programs/haskell2010/lazy-argument.hs
# 1
```

Compile a current supported `.hg` program to a native executable:

```bash
cabal run haskell-compiler -- compile examples/llvm/arithmetic.hg -o /tmp/haskell-compiler-arithmetic
/tmp/haskell-compiler-arithmetic
# 14
```

Compile a supported Haskell 2010 `.hs` program to a native executable:

```bash
cabal run haskell-compiler -- compile test/e2e/programs/haskell2010/lazy-argument.hs -o /tmp/haskell-compiler-hs
/tmp/haskell-compiler-hs
# 1
```

Emit LLVM IR instead of a native executable:

```bash
cabal run haskell-compiler -- compile examples/llvm/arithmetic.hg --emit-llvm -o /tmp/haskell-compiler-arithmetic.ll
```

Compile without Egglog optimization:

```bash
cabal run haskell-compiler -- compile examples/llvm/division.hg -o /tmp/haskell-compiler-division --no-egglog
```

The same `--no-egglog` flag disables the Haskell 2010 Core optimizer for `.hs`
Core-0 programs. Use `--strict-egglog` on `check`, `compile`, `emit-core`,
`emit-stg`, `report`, or `run` when an unsupported Egglog optimization fallback
should be reported as an error instead of producing unoptimized output.

## Haskell 2010 Roadmap

- [Haskell 2010 roadmap](docs/haskell2010-roadmap.md)
- [Haskell 2010 engineering backlog](docs/haskell2010-todo.md)
- [Haskell 2010 conformance matrix](docs/haskell2010-conformance-matrix.md)
- [Haskell 2010 conformance results](docs/haskell2010-conformance-results.md)
- [Haskell 2010 implementation plan](docs/haskell2010-implementation-plan.md)
- [Haskell 2010 frontend specification](docs/haskell2010-frontend-spec.md)
- [Haskell 2010 status summary](docs/haskell2010-status-summary.md)
- [Design document completion audit](docs/design-doc-completion-audit.md)
- [Examples and tutorial documentation plan](docs/examples-tutorial-plan.md)
- [CI matrix](docs/ci.md)
- [clang and LLVM toolchain](docs/llvm-toolchain.md)
- [Release workflow](docs/release-workflow.md)
- [Release checklist](docs/release-checklist.md)
- [Versioning policy](docs/versioning-policy.md)
- [Changelog](CHANGELOG.md)
- [Installation](docs/installation.md)
- [Examples gallery](docs/examples-gallery.md)
- [Runtime build integration](docs/runtime-build-integration.md)
- [Formatting and linting](docs/formatting-linting.md)
- [Coverage reporting](docs/coverage.md)
- [Benchmark suite](docs/benchmarks.md)
- [Standard library packaging](docs/standard-library-packaging.md)
- [Laziness and STG plan](docs/laziness-and-stg-plan.md)
- [Egglog Core optimizer plan](docs/egglog-core-optimizer-plan.md)

The detailed Haskell 2010 engineering backlog is tracked in
[docs/haskell2010-todo.md](docs/haskell2010-todo.md).

Full documentation index:

- [docs/index.md](docs/index.md)

## Current Compiler vs Haskell 2010 Target

| Area | Status |
| --- | --- |
| Current `.hg` strict subset | Implemented and tested. |
| Haskell 2010 parser/layout | Implemented as an isolated parser/layout frontend, parser-tested, and connected to the executable `.hs` compile path. |
| Haskell 2010 renamer/modules | Implemented as an isolated unique-name pass with module graph loading, search paths, export/import filtering, qualified aliases, hiding, `Thing(..)` children, implicit/explicit Prelude behavior, instance import/export movement, and root-module `main` selection for the executable subset. |
| Haskell 2010 typed Core | Implemented as a typed IR with validator, free-variable analysis, substitution, pretty-printer, and source generation for the executable subset. |
| Haskell 2010 typechecker/desugarer | Implemented for explicit signatures, HM polymorphism, functions, lambdas, application, `let`/`where`, `if`, cases, guards, as-patterns, lazy patterns, ADTs, records, newtypes, lists/tuples, recursion, user-defined class dictionaries, deriving for supported classes, Report-shaped `Show`/`Read`, numeric defaulting, standard-library module interfaces, IO/do-notation, module imports, and FFI signature validation for the supported ABI slice. |
| Haskell 2010 Core reference evaluator | Implemented for validating typed Core with lazy let/function/constructor-field thunks, erased Core type abstraction/application, Bool/user/list/tuple/Prelude-data case execution, generated Prelude/library functions, user and built-in class dictionary calls, IO actions including input/error behavior, checked numeric primitives, structured runtime errors, and source attribution. |
| Haskell 2010 STG/lazy runtime | Implemented as an isolated STG-like IR, validator, heap evaluator, Core-to-STG lowering, and boxed LLVM/native runtime for the current executable subset, including thunks, enter/apply, constructor dispatch, dictionary execution, IO actions, checked primitives, foreign-call/export metadata, and native wet tests. |
| Haskell 2010 conformance baseline | Implemented as the mandatory `haskell2010-conformance-test` Cabal suite. It reads `test/haskell2010/conformance/manifest.json`, invokes the built `haskell-compiler` executable as a subprocess, compiles and runs native artifacts directly, checks exact stdout, and verifies runtime-error, compile-error, and unsupported-documented cases. |
| LLVM/native backend | Implemented for the current `.hg` supported subset and the documented Haskell 2010 executable subset, including native IO, libraries, FFI imports/exports, runtime helpers, and explicit native link inputs. |
| Egglog ANF backend | Implemented for the current `.hg` supported subset. |
| Egglog Core optimizer | Implemented for safe Haskell 2010 Core fragments using typed Core validation, provenance, totality/no-error/demand/strictness facts, known-constructor rewrites, known-dictionary facts, dictionary simplification, and optimized/unoptimized native agreement tests. |
| Native wet tests | Implemented for the current `.hg` native compiler baseline and the Haskell 2010 executable native path, including default Egglog and `--no-egglog` modes. |
| Release engineering | Implemented and documented for the current repo shape: CI matrix, LLVM/clang toolchain docs, install instructions, examples gallery, standard-library packaging docs, runtime build smoke tests, linting, coverage reporting, benchmarks, release workflow, release checklist, versioning policy, and changelog. |

## Current `.hg` Language Support

Report/interpreter mode supports the implemented strict expression language:

- checked signed `Int64`
- `Bool`
- variables
- nonrecursive `let`
- `if`
- integer `+`, `-`, `*`, and `/`
- integer `<`
- `==` over `Int` and `Bool`
- lambda expressions
- function application
- ordered nonrecursive top-level first-order function definitions
- local higher-order functions
- optional lambda parameter annotations when monomorphic inference is concrete

The LLVM/native backend is narrower than report mode. It supports closed
programs with printable `Int` or `Bool` roots, top-level first-order calls,
lambda-lifted non-capturing functions, and closure-converted local function
values. It rejects unsupported targets structurally.

Haskell Compiler now supports whole-program Haskell 2010 source graphs through
explicit files and import search paths, the documented executable
pattern-matching subset, user and Prelude-backed classes, superclass/default
method behavior, supported deriving, real `Char`/`String` list representation,
Report-shaped `Show` and `Read`, broad generated Prelude/library interfaces,
`main :: IO ()`, `putStrLn`, `getLine`, `print`, `System.IO`,
`System.Environment`, `System.Exit`, and the supported Haskell 2010 FFI surface.

The compiler still makes no claim to GHC package databases, persistent
interface-file separate compilation, arbitrary third-party package builds, or
behavior outside the documented native conformance matrix. Unsupported or
out-of-scope behavior should remain explicit in docs and fixtures.

## Existing Specs

- [Current capabilities](docs/current-capabilities.md)
- [Full compiler definition](docs/full-compiler-definition.md)
- [Language specification for `.hg`](docs/language-spec.md)
- [Runtime specification](docs/runtime-spec.md)
- [Diagnostics specification](docs/diagnostics-spec.md)
- [Optimizer specification](docs/optimizer-spec.md)
- [Egglog engine specification](docs/egglog-engine-spec.md)
- [Egglog backend](docs/egglog-backend.md)
- [LLVM backend](docs/llvm-backend.md)
- [LLVM backend specification](docs/llvm-backend-spec.md)
- [Type inference direction](docs/type-inference.md)
- [End-to-end wet testing](docs/e2e-wet-testing.md)
- [Recorded wet-test results](docs/e2e-results.md)
- [Haskell 2010 conformance results](docs/haskell2010-conformance-results.md)

## CI

CI runs `scripts/lint.sh`, `cabal build all`, `cabal test all
--test-options='--hide-successes'`, `cabal check`, strict native smoke tests,
installation/examples/standard-library/runtime-build smoke tests, mandatory
clang-backed end-to-end wet tests, and a dedicated Ubuntu coverage report job on
pushes to `main`/`develop` and on pull requests. CI also runs a dedicated
Ubuntu benchmark job that validates representative compiler workflows and
writes benchmark artifacts. The Haskell 2010 conformance suite is part of
`cabal test all` and is not optional.

## License

Haskell Compiler is licensed under the MIT License. See [LICENSE](LICENSE).
