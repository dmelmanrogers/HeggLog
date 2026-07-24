# Examples And Tutorial Documentation Plan

Status: complete for `DOC-004`.

This plan defines how Haskell Compiler examples and tutorials are organized for the
Haskell 2010 native compiler target. It deliberately separates the plan from
the gallery implementation owned by `REL-006`.

## Goals

- Teach the supported compiler pipeline from source file to native executable.
- Prefer examples that are already exercised by unit, conformance, or wet
  tests.
- Keep `.hg` substrate examples visible as legacy infrastructure examples, not
  as Haskell 2010 language examples.
- Make unsupported behavior explicit through negative or
  unsupported-documented fixtures rather than prose-only warnings.
- Keep every tutorial command runnable from a fresh checkout.

## Audiences

| Audience | Needs | Primary docs |
| --- | --- | --- |
| Compiler contributor | Understand stage contracts and debug IR | `docs/architecture.md`, `docs/egglog-core-optimizer-plan.md`, `docs/llvm-backend-spec.md` |
| Haskell 2010 user | Compile and run examples | `README.md`, `docs/installation.md`, `docs/examples-gallery.md` |
| Release maintainer | Verify examples do not drift | `docs/release-checklist.md`, `scripts/release-check.sh` |
| Conformance reviewer | Map examples to Haskell 2010 coverage | `docs/haskell2010-conformance-matrix.md`, `test/haskell2010/conformance/manifest.json` |

## Tutorial Sequence

The tutorial path should introduce capabilities in this order:

1. Build the compiler with `cabal build all`.
2. Check a Haskell 2010 source file with `haskell-compiler check`.
3. Emit Core with `haskell-compiler emit-core --both`.
4. Emit STG with `haskell-compiler emit-stg`.
5. Run a source file directly with `haskell-compiler run`.
6. Compile a native executable with `haskell-compiler compile`.
7. Use `--no-egglog` and `--strict-egglog` to inspect optimizer behavior.
8. Preserve generated files with `--keep-intermediates`.
9. Compile a multi-module program through `--import-path`.
10. Compile examples that exercise IO, standard-library imports, typeclasses,
    deriving, FFI, and runtime errors.

## Example Tiers

| Tier | Location | Purpose | Validation |
| --- | --- | --- | --- |
| Quickstart | `examples/` | Small `.hg` substrate smoke programs | `scripts/smoke-test.sh` |
| Native Haskell 2010 examples | `test/e2e/programs/haskell2010/` and later curated copies under `examples/haskell2010/` | End-user Haskell 2010 compiler behavior | `e2e-wet-test` |
| Conformance fixtures | `test/haskell2010/conformance/` | Manifest-backed Haskell 2010 coverage | `haskell2010-conformance-test` and `scripts/validate-haskell2010-conformance.py` |
| Negative examples | `examples/type-errors/` and conformance negative fixtures | Diagnostics and rejection behavior | unit diagnostics tests and conformance compile-error rows |

## Gallery Acceptance Rules

`REL-006` should only publish an example in `docs/examples-gallery.md` when:

- the source file is committed in the repository;
- the expected command line is documented;
- expected stdout/stderr/exit behavior is documented;
- the example is covered by a unit test, conformance fixture, wet test, or
  release smoke check;
- the example uses the public CLI rather than internal helper modules;
- the example is not described as broader Haskell 2010 support than the
  conformance matrix currently validates.

## Tutorial Drift Controls

- `scripts/validate-doc-links.py` checks local documentation links.
- `scripts/validate-haskell2010-conformance.py` checks the conformance matrix
  and manifest.
- `scripts/validate-haskell2010-todo.py` checks tracker consistency.
- `REL-006` will add gallery-specific examples and `REL-012` will require the
  release checklist to run the public commands shown in the quickstart path.
