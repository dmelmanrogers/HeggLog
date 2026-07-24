# Installation

Status: complete for `REL-004`.

Haskell Compiler is installed from source with Cabal. The release-quality installation
path installs the `haskell-compiler` executable and verifies that the installed binary
can check, compile, and run a Haskell 2010 program.

## Prerequisites

- GHC `9.10.1`
- Cabal `3.12.1.0`
- `clang`
- `llvm-as`
- `lli`

Install and validate the native toolchain first:

```bash
scripts/check-native-toolchain.sh
```

See `docs/llvm-toolchain.md` for macOS and Ubuntu package commands.

## Build From Source

```bash
cabal update
cabal build all
cabal test all --test-options='--hide-successes'
```

## Install The Executable

Install to a chosen prefix:

```bash
mkdir -p "$HOME/.local/bin"
cabal install exe:haskell-compiler \
  --installdir="$HOME/.local/bin" \
  --overwrite-policy=always \
  --install-method=copy
```

Make sure the install directory is on `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
haskell-compiler --help
```

## Verify The Installed Compiler

Run:

```bash
haskell-compiler check test/e2e/programs/haskell2010/lazy-argument.hs
haskell-compiler compile test/e2e/programs/haskell2010/lazy-argument.hs -o /tmp/haskell-compiler-lazy
/tmp/haskell-compiler-lazy
```

Expected output:

```text
1
```

## Automated Install Smoke Test

The repository includes an isolated install smoke test:

```bash
scripts/install-smoke-test.sh
```

The script installs `haskell-compiler` into a temporary prefix, checks the public help
text, typechecks a Haskell 2010 example, compiles it to a native executable, and
verifies the executable output.
