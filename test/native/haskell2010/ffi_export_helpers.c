#include <stdint.h>

extern int64_t haskell_compiler_hs_export_add(int64_t lhs, int64_t rhs);
extern int64_t haskell_compiler_hs_export_io(int64_t value);

int64_t haskell_compiler_ffi_call_export_add(int64_t lhs, int64_t rhs) {
  return haskell_compiler_hs_export_add(lhs, rhs);
}

int64_t haskell_compiler_ffi_call_export_io(int64_t value) {
  return haskell_compiler_hs_export_io(value);
}
