# Formatting And Linting

Status: complete for `REL-009`.

The repository uses a pragmatic lint gate that relies only on tools already
required for development and release validation.

## Lint Gate

Run:

```bash
scripts/lint.sh
```

The lint gate checks:

- shell script syntax with `bash -n`;
- executable bits for tracked shell scripts under `scripts/`;
- Python script syntax with `python3 -m py_compile`;
- Markdown links;
- Haskell 2010 backlog consistency;
- Haskell 2010 conformance matrix consistency;
- CI workflow shape;
- examples gallery references;
- whitespace with `git diff --check`;
- Cabal package metadata with `cabal check`;
- Haskell build cleanliness under the package's `-Wall` warning profile with
  `cabal build all`.

## Style Rules

- Do not commit generated build artifacts from `.context` or `dist-newstyle`.
- Keep release scripts executable and syntax-checkable.
- Keep documentation links relative when linking within the repository.
- Keep tracker status synchronized between `docs/haskell2010-todo.md` and
  `docs/haskell2010-todo.json`.
- Prefer public CLI smoke scripts over undocumented manual validation steps.

## CI

CI runs `scripts/lint.sh` in the docs/tracker job and still runs the full
platform matrix separately.
