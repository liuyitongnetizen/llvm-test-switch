//===-- Libc specific custom operator new and delete ------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIBC_SRC___SUPPORT_CPP_NEW_H
#define LLVM_LIBC_SRC___SUPPORT_CPP_NEW_H

#include "hdr/func/aligned_alloc.h"
#include "hdr/func/free.h"
#include "hdr/func/malloc.h"
#include "src/__support/common.h"
#include "src/__support/macros/config.h"
#include "src/__support/macros/properties/os.h"

#include <stddef.h> // For size_t

// Defining members in the std namespace is not preferred. But, we do it here
// so that we can use it to define the operator new which takes std::align_val_t
// argument.
namespace std {

enum class align_val_t : size_t {};

} // namespace std

namespace LIBC_NAMESPACE_DECL {

namespace cpp {
template <class T> [[nodiscard]] constexpr T *launder(T *p) {
  static_assert(__has_builtin(__builtin_launder),
                "cpp::launder requires __builtin_launder");
  return __builtin_launder(p);
}
} // namespace cpp

class AllocChecker {
  bool success = false;

  LIBC_INLINE AllocChecker &operator=(bool status) {
    success = status;
    return *this;
  }

public:
  LIBC_INLINE AllocChecker() = default;

  LIBC_INLINE operator bool() const { return success; }

  LIBC_INLINE static void *alloc(size_t s, AllocChecker &ac) {
    void *mem = ::malloc(s);
    ac = (mem != nullptr);
    return mem;
  }

  LIBC_INLINE static void *aligned_alloc(size_t s, std::align_val_t align,
                                         AllocChecker &ac) {
#ifdef LIBC_TARGET_OS_IS_WINDOWS
    // std::aligned_alloc is not available on Windows because std::free on
    // Windows cannot deallocate any over-aligned memory. Microsoft provides an
    // alternative for std::aligned_alloc named _aligned_malloc, but it must be
    // paired with _aligned_free instead of std::free.
    void *mem = ::_aligned_malloc(static_cast<size_t>(align), s);
#else
    void *mem = ::aligned_alloc(static_cast<size_t>(align), s);
#endif
    ac = (mem != nullptr);
    return mem;
  }
};

} // namespace LIBC_NAMESPACE_DECL

LIBC_INLINE void *operator new(size_t size,
                               LIBC_NAMESPACE::AllocChecker &ac) noexcept {
  return LIBC_NAMESPACE::AllocChecker::alloc(size, ac);
}

LIBC_INLINE void *operator new(size_t size, std::align_val_t align,
                               LIBC_NAMESPACE::AllocChecker &ac) noexcept {
  return LIBC_NAMESPACE::AllocChecker::aligned_alloc(size, align, ac);
}

LIBC_INLINE void *operator new[](size_t size,
                                 LIBC_NAMESPACE::AllocChecker &ac) noexcept {
  return LIBC_NAMESPACE::AllocChecker::alloc(size, ac);
}

LIBC_INLINE void *operator new[](size_t size, std::align_val_t align,
                                 LIBC_NAMESPACE::AllocChecker &ac) noexcept {
  return LIBC_NAMESPACE::AllocChecker::aligned_alloc(size, align, ac);
}

LIBC_INLINE void *operator new(size_t, void *p) { return p; }

LIBC_INLINE void *operator new[](size_t, void *p) { return p; }

// The ideal situation would be to define the various flavors of operator delete
// inlinelike we do with operator new above. However, since we need operator
// delete prototypes to match those specified by the C++ standard, we cannot
// define them inline as the C++ standard does not allow inline definitions of
// replacement operator delete implementations. Note also that we assign a
// special linkage name to each of these replacement operator delete functions.
// This is because, if we do not give them a special libc internal linkage name,
// they will replace operator delete for the entire application. Including this
// header file in all libc source files where operator delete is called ensures
// that only libc call sites use these replacement operator delete functions.

#define DELETE_NAME(name)                                                      \
  __asm__(LIBC_MACRO_TO_STRING(LIBC_NAMESPACE) "_" LIBC_MACRO_TO_STRING(name))

void operator delete(void *) noexcept DELETE_NAME(delete);
void operator delete(void *, std::align_val_t) noexcept
    DELETE_NAME(delete_aligned);
void operator delete(void *, size_t) noexcept DELETE_NAME(delete_sized);
void operator delete(void *, size_t, std::align_val_t) noexcept
    DELETE_NAME(delete_sized_aligned);
void operator delete[](void *) noexcept DELETE_NAME(delete_array);
void operator delete[](void *, std::align_val_t) noexcept
    DELETE_NAME(delete_array_aligned);
void operator delete[](void *, size_t) noexcept DELETE_NAME(delete_array_sized);
void operator delete[](void *, size_t, std::align_val_t) noexcept
    DELETE_NAME(delete_array_sized_aligned);

#undef DELETE_NAME

#endif // LLVM_LIBC_SRC___SUPPORT_CPP_NEW_H
