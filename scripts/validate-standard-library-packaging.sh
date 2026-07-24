#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/haskell-compiler-stdlib.XXXXXX")"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

source_file="$tmpdir/Main.hs"

cat >"$source_file" <<'EOF'
module Main where

import qualified Control.Monad as M01
import qualified Data.Array as M02
import qualified Data.Bits as M03
import qualified Data.Char as M04
import qualified Data.Complex as M05
import qualified Data.Int as M06
import qualified Data.Ix as M07
import qualified Data.List as M08
import qualified Data.Maybe as M09
import qualified Data.Ratio as M10
import qualified Data.Word as M11
import qualified Foreign as M12
import qualified Foreign.C as M13
import qualified Foreign.C.Error as M14
import qualified Foreign.C.String as M15
import qualified Foreign.C.Types as M16
import qualified Foreign.ForeignPtr as M17
import qualified Foreign.Marshal as M18
import qualified Foreign.Marshal.Alloc as M19
import qualified Foreign.Marshal.Array as M20
import qualified Foreign.Marshal.Error as M21
import qualified Foreign.Marshal.Utils as M22
import qualified Foreign.Ptr as M23
import qualified Foreign.StablePtr as M24
import qualified Foreign.Storable as M25
import qualified Numeric as M26
import qualified System.Environment as M27
import qualified System.Exit as M28
import qualified System.IO as M29
import qualified System.IO.Error as M30

main = 0
EOF

printf '== standard library package import check ==\n'
cabal run -v0 haskell-compiler -- check "$source_file"

printf 'standard library packaging validation passed\n'
