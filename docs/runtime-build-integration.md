# Runtime Build Integration

Status: complete for `REL-008`.

The runtime build integration boundary is the public native compilation path:

```text
Haskell 2010 source
  -> typed Core
  -> optimized Core
  -> validated STG
  -> boxed lazy runtime LLVM
  -> object file
  -> clang-linked executable
```

The runtime is emitted as LLVM definitions and declarations by the backend.
There is no separate untracked runtime object that must be manually copied into
release builds. Native build integration is therefore validated by compiling
through the public CLI and preserving the generated intermediates.

## Validation

Run:

```bash
scripts/runtime-build-smoke.sh
```

The smoke test:

- validates `clang`, `llvm-as`, and `lli`;
- compiles a lazy Haskell 2010 program with `--keep-intermediates`;
- verifies the native executable exists and runs;
- verifies the generated LLVM and object intermediates exist;
- checks the LLVM text for the lazy-runtime marker and process/runtime globals.

The release gate and CI run this smoke test in addition to the full native wet
tests.
