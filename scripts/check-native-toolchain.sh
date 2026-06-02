#!/usr/bin/env bash
set -euo pipefail

missing=0

require_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '%s is required but was not found on PATH\n' "$tool" >&2
    missing=1
    return
  fi
  printf '== %s ==\n' "$tool"
  "$tool" --version | head -n 1
}

require_tool clang
require_tool llvm-as
require_tool lli

if [[ "$missing" -ne 0 ]]; then
  cat >&2 <<'EOF'

Install a native LLVM toolchain before running strict native or release tests:

  macOS:   brew install llvm
           export PATH="$(brew --prefix llvm)/bin:$PATH"

  Ubuntu:  sudo apt-get update
           sudo apt-get install -y clang llvm

EOF
  exit 1
fi
