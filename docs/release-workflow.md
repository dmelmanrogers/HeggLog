# Release Workflow

Status: complete for `REL-003`.

The release workflow is the ordered process for turning a verified commit on
`main` into a tagged Haskell Compiler release. It is intentionally conservative: release
automation must never claim broader compiler support than the tracker,
conformance matrix, and wet tests validate.

## Release Gate

Run the release gate from the repository root:

```bash
scripts/release-check.sh
```

The gate performs:

1. Native toolchain validation.
2. Lint gate, including documentation links, tracker validation, conformance
   matrix validation, CI workflow shape validation, release checklist
   validation, examples gallery validation, whitespace validation, Cabal
   package metadata validation, and `cabal build all`.
3. `cabal build all`.
4. `cabal test all --test-options='--hide-successes'`.
5. Strict native smoke tests.
6. Installation smoke test.
7. Examples gallery smoke test.
8. Standard-library packaging validation.
9. Runtime build integration smoke test.
10. Coverage report generation.
11. Benchmark suite.
12. Mandatory end-to-end wet tests.
13. Cabal source distribution generation.

## Human Release Procedure

1. Start from the release branch or `main` after the release PR is merged.
2. Confirm the working tree is clean:

   ```bash
   git status --short
   ```

3. Confirm the version, changelog, release checklist, and tracker all agree.
4. Run:

   ```bash
   scripts/release-check.sh
   ```

5. Create a signed or annotated tag according to `docs/versioning-policy.md`.
6. Publish the tag and release notes.
7. Confirm CI passes on the tag or release branch.

## Release Invariants

- Release notes must cite the exact version and commit.
- The release checklist must not override failing tests.
- Unsupported features must remain explicit in the conformance matrix.
- Release artifacts must be built from committed source, not local generated
  files under `.context` or `dist-newstyle`.
- Native release validation requires `clang`, `llvm-as`, and `lli`.

## Validation

This workflow is validated by:

```bash
bash -n scripts/release-check.sh
scripts/check-native-toolchain.sh
python3 scripts/validate-doc-links.py
python3 scripts/validate-haskell2010-todo.py
python3 scripts/validate-haskell2010-conformance.py
python3 scripts/validate-ci-matrix.py
python3 scripts/validate-release-checklist.py
python3 scripts/validate-versioning.py
```
