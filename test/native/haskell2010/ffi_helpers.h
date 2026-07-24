#ifndef HASKELL_COMPILER_HASKELL2010_FFI_HELPERS_H
#define HASKELL_COMPILER_HASKELL2010_FFI_HELPERS_H

#include <stdint.h>

int64_t haskell_compiler_ffi_add_i64(int64_t lhs, int64_t rhs);
void haskell_compiler_ffi_reset(void);
int64_t haskell_compiler_ffi_accum(int64_t value);
int64_t haskell_compiler_ffi_current(void);
int64_t haskell_compiler_ffi_bool_to_i64(uint8_t value);
int32_t haskell_compiler_ffi_next_char(int32_t value);
uint8_t haskell_compiler_ffi_inc_u8(uint8_t value);
int8_t haskell_compiler_ffi_neg_i8(int8_t value);
uint64_t haskell_compiler_ffi_id_u64(uint64_t value);
void haskell_compiler_ffi_reset_finalizers(void);
void haskell_compiler_ffi_count_i64_finalizer(int64_t *ptr);
void haskell_compiler_ffi_count_i64_finalizer_one(int64_t *ptr);
void haskell_compiler_ffi_count_i64_finalizer_two(int64_t *ptr);
int64_t haskell_compiler_ffi_finalizer_total_value(void);
int64_t haskell_compiler_ffi_finalizer_order_value(void);

#endif
