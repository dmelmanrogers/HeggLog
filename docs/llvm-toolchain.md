# clang and LLVM Toolchain

Status: complete for `REL-002`.

HeggLog emits LLVM IR and uses the platform native toolchain for executable
wet tests and release builds. Release-quality native validation requires these
tools on `PATH`:

- `clang`
- `llvm-as`
- `lli`

The shared toolchain probe is:

```bash
scripts/check-native-toolchain.sh
```

That script prints tool versions and exits nonzero if any required tool is
missing.

## macOS

Install LLVM with Homebrew:

```bash
brew install llvm
export PATH="$(brew --prefix llvm)/bin:$PATH"
```

Apple's system `clang` is usually present, but Homebrew LLVM is still required
for `llvm-as` and `lli`. CI adds the Homebrew LLVM `bin` directory to `PATH`
for this reason.

## Ubuntu

Install clang and LLVM:

```bash
sudo apt-get update
sudo apt-get install -y clang llvm
```

This provides the native compiler and LLVM tools used by CI.

## Validation Commands

Strict native and release-quality checks require the full toolchain:

```bash
scripts/check-native-toolchain.sh
scripts/smoke-test.sh --strict-native
scripts/e2e-wet-test.sh
```

When `scripts/smoke-test.sh` is run without `--strict-native`, native smoke
tests may be skipped if `clang` is unavailable. Release checks and CI never use
that relaxed mode.
