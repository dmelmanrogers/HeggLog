# Versioning Policy

Haskell Compiler uses the Cabal package version as the authoritative release version.
The current package version is `1.1.0.0`.

## Version Format

Package versions use four numeric components:

```text
MAJOR.MINOR.PATCH.REVISION
```

This matches Cabal/PVP-compatible version syntax and keeps Haskell package
metadata, tags, release notes, and changelog entries aligned.

## Increment Rules

- Increment `MAJOR` for incompatible command-line, source-language,
  conformance-claim, or package-boundary changes.
- Increment `MINOR` for new supported compiler functionality, new standard
  library surface, new release tooling, or other user-visible capabilities that
  preserve existing supported behavior.
- Increment `PATCH` for bug fixes, diagnostics improvements, correctness fixes,
  documentation corrections, and internal release-quality improvements that do
  not expand the support claim.
- Increment `REVISION` only for package metadata corrections that do not change
  source code, generated artifacts, runtime behavior, or documented support.

When a change could fit multiple categories, choose the larger increment.
Correctness, conformance, and support-claim clarity take precedence over
minimizing version movement.

## Release Tags

Release tags use the Cabal version prefixed with `v`:

```text
v1.1.0.0
```

Tags must point at committed source that passed `scripts/release-check.sh`.
Generated files under `.context` and `dist-newstyle` are never release inputs.

## Changelog Alignment

Every released version must have a [changelog](../CHANGELOG.md) section with
the same version number. The changelog section should summarize:

- compiler functionality added or changed
- Haskell 2010 conformance claim changes
- standard-library/runtime/backend changes
- release tooling, CI, installation, coverage, benchmark, and packaging changes
- known unsupported or explicitly documented behavior

## Validation

Run:

```bash
python3 scripts/validate-versioning.py
```

The validator checks the Cabal version format and verifies that this policy
references the current package version.
