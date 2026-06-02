# Standard Library Packaging

Status: complete for `REL-007`.

HeggLog packages the implemented Haskell 2010 standard library as an internal
virtual library owned by `Haskell2010.StandardLibrary`. That module is the
single release boundary for generated interfaces and source-backed virtual
modules.

## Package Model

The standard-library package has three kinds of entries:

- generated interfaces, such as `Prelude`, fixed-width numeric modules,
  process/IO modules, and FFI helper modules;
- source-backed virtual modules, such as `Data.List`, `Data.Maybe`,
  `Data.Char`, `Data.Array`, `Data.Complex`, and `Numeric`;
- reserved modules, which must remain unimportable until they have real
  parser, renamer, typechecker, Core/STG, native, and conformance support.

Generated and source-backed modules both flow through `ModuleInterface`.
Exported names, `Thing(..)` children, fixities, and instance exports therefore
use the same data model as user modules.

## Importable Module Surface

The release package currently exposes these standard modules:

- `Prelude`
- `Control.Monad`
- `Data.Array`
- `Data.Bits`
- `Data.Char`
- `Data.Complex`
- `Data.Int`
- `Data.Ix`
- `Data.List`
- `Data.Maybe`
- `Data.Ratio`
- `Data.Word`
- `Foreign`
- `Foreign.C`
- `Foreign.C.Error`
- `Foreign.C.String`
- `Foreign.C.Types`
- `Foreign.ForeignPtr`
- `Foreign.Marshal`
- `Foreign.Marshal.Alloc`
- `Foreign.Marshal.Array`
- `Foreign.Marshal.Error`
- `Foreign.Marshal.Utils`
- `Foreign.Ptr`
- `Foreign.StablePtr`
- `Foreign.Storable`
- `Numeric`
- `System.Environment`
- `System.Exit`
- `System.IO`
- `System.IO.Error`

## Validation

Run:

```bash
scripts/validate-standard-library-packaging.sh
```

The validator builds a temporary module that imports every advertised standard
library module through the public `hegglog check` command. It fails if a module
is missing from the virtual package boundary or cannot be loaded by the module
graph.

The broader per-value library semantics remain covered by:

```bash
python3 scripts/validate-haskell2010-conformance.py
cabal test haskell2010-conformance-test --test-options='--hide-successes'
```
