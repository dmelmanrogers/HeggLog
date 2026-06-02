# Examples Gallery

Status: complete for `REL-006`.

This gallery points to curated examples that exercise the public HeggLog CLI.
Every listed source file is committed in the repository and covered by
`scripts/examples-gallery-smoke.sh`, conformance fixtures, wet tests, or both.

## Lazy Evaluation

File: `examples/haskell2010/lazy-argument.hs`

```bash
hegglog run examples/haskell2010/lazy-argument.hs
```

Expected output:

```text
1
```

This demonstrates that an unused bottom-producing argument is not evaluated.

## Recursion

File: `examples/haskell2010/fibonacci.hs`

```bash
hegglog run examples/haskell2010/fibonacci.hs
```

Expected output:

```text
21
```

## IO and Show

File: `examples/haskell2010/io-and-show.hs`

```bash
hegglog check examples/haskell2010/io-and-show.hs
hegglog compile examples/haskell2010/io-and-show.hs -o /tmp/hegglog-io-and-show
/tmp/hegglog-io-and-show
```

This exercises `IO`, `do`, `return`, `(>>=)`, `putStrLn`, `print`, `Char`,
`String`, lists, and supported `Show` dictionaries.

## User Typeclasses

File: `examples/haskell2010/typeclass-dictionary.hs`

```bash
hegglog run examples/haskell2010/typeclass-dictionary.hs
```

Expected output:

```text
1
```

This exercises user class dictionaries and constrained functions.

## Standard Library Imports

File: `examples/haskell2010/standard-library.hs`

```bash
hegglog check examples/haskell2010/standard-library.hs
hegglog compile examples/haskell2010/standard-library.hs -o /tmp/hegglog-standard-library
/tmp/hegglog-standard-library
```

This exercises import lists from `Control.Monad`, `Data.List`, `Data.Maybe`,
and `System.IO`.

## Multi-Module Compilation

Files:

- `examples/haskell2010/modules/Main.hs`
- `examples/haskell2010/modules/Lib.hs`

```bash
hegglog compile \
  examples/haskell2010/modules/Main.hs \
  --import-path examples/haskell2010/modules \
  -o /tmp/hegglog-modules
/tmp/hegglog-modules
```

Expected output:

```text
20
```

## Validation

Run:

```bash
python3 scripts/validate-examples-gallery.py
scripts/examples-gallery-smoke.sh
```
