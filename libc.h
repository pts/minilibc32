/* by pts@fazekas.hu at Sun Nov 27 13:52:31 CET 2022 */

#ifndef _LIBC_H
#define _LIBC_H 1

#undef __LIBC_OK

#if defined(__WATCOMC__) && !defined(__GNUC__) && defined(_M_I386)
#  define __LIBC_OK 1
#else
#  if defined(__GNUC__) && !defined(__WATCOMC__) && defined(__i386__)
#    define __LIBC_OK 1
#  else
#    error Unsupported libc target.
#  endif
#endif
#ifndef __LIBC_OK
#  define __LIBC_OK 0
#endif
#if __LIBC_OK

#ifdef __GNUC__
#  define __LIBC_CALL __attribute__((regparm(3)))
#  define __LIBC_FUNC(name, args) __LIBC_CALL name args __asm__(#name "__RP3__")
#  define __LIBC_NORETURN __attribute__((noreturn, nothrow))
#else
#  define __LIBC_CALL __watcall
#  define __LIBC_FUNC(name, args) __LIBC_CALL name args
#  define __LIBC_NORETURN __declspec(aborts)
#endif

#define open open3  /* Avoid using the OpenWatcom C compiler using the `...' form. TODO(pts): Rename assembly symbols in OpenWatcom. */

#ifdef __WATCOMC__
#define main main_from_libc  /* TODO(pts): Rename at assembler level, add symbol alias here. For OpenWatcom. */
extern int __LIBC_CALL main(int argc, char **argv);
#endif

#define NULL ((void*)0)

#define SEEK_SET 0  /* whence value below. */
#define SEEK_CUR 1
#define SEEK_END 2

#define O_RDONLY 0  /* flags bitfield value below. */
#define O_WRONLY 1
#define O_RDWR   2
/* Linux-specific. */
#define O_CREAT 0100
#define O_TRUNC 01000
/* TODO(pts): We are not specifying O_APPEND, because WDOSX and MWPESTUB don't support it. `#define O_APPEND 02000' */

#define STDIN_FILENO  0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2

#define EXIT_SUCCESS 0  /* status values below. Can be 0..255. */
#define EXIT_FAILURE 1

typedef unsigned size_t;
typedef int ssize_t;
typedef unsigned mode_t;
typedef long off_t;  /* Not implemented: 64-bit off_t (#define _FILE_OFFSET_BITS 64), off64_r, lseek64(2). */
typedef int pid_t;

/* --- 64-bit integer multiplication, division, modulo and shifts. */

#if 0 && defined(__GNUC__)  /* This doesn't help, GCC still calls them with regparm(3), see also https://patchwork.ozlabs.org/project/uboot/patch/20171117060228.23926-1-sr@denx.de/ for a workaround. */
__extension__ extern unsigned long long __attribute__((regparm(0))) __udivdi3(unsigned long long a, unsigned long long b);
__extension__ extern unsigned long long __attribute__((regparm(0))) __umoddi3(unsigned long long a, unsigned long long b);
__extension__ extern long long __attribute__((regparm(0))) __divdi3(long long a, long long b);
__extension__ extern long long __attribute__((regparm(0))) __moddi3(long long a, long long b);
#endif

/* --- ABI detection (abitest): regparm(0) vs regparm(3). */

#ifdef __GNUC__
#if 0
/* Predeclare to make sure that default -mregparm=... is used for main(...)
 * as regparm(...). This protects against an explicit
 * `__attribute__((regparm(...))) int main(...) { ... }'.
 *
 * We don't do it, because it would prevent `int main(void) { ... }' from
 * working.
 */
extern int main(int argc, char **argv);
#endif

/* To check which -mregparm=0 ... -regparm=3 was used for compilation,
 * irrespective of the GCC optimization level: If there is a `sub esp, sv'
 * instruction, remember sv. Othervise let sv be 0. Count the number of
 * [esp+...] (only displacements larger than sv) and [ebp+...] (only
 * positive displacements) effective addresses in the function code: c. Then
 * the regparm value is (3 - c).
 */
__attribute__((used)) static int __abitest_retsum(int a1, int a2, int a3) { return a1 + a2 + a3; }
/* To check which regparm(...) value GCC is using for calling __divdi3,
 * distinguishing between 0 and 3, irrespective of the GCC optimization
 * level: Check the block of `push' and `mov' instructions preceding the
 * `call __divdi3' instruction. If there are 4 `push [ebp+...]' or `push
 * [ebp+...]' instructions, then it's regparm(0). Otherwise, if there are 2
 * `push [ebp+...]' or `push [esp+...]' instructions and a `mov eax,
 * [...+...]' and a `mov edx, [...+...]' then it's regparm(3). Otherwise the
 * detection has failed.
 *
 * As a side effect, this code adds `.globl __divdi3' to the assembly
 * source code, making this object file unnecessarily depend on __divdi3. A
 * specialized linker can get easily rid of this reference (and
 * __abitest_divdi3 itself).
 */
__extension__ __attribute__((used)) __attribute__((regparm(0))) static long long __abitest_divdi3(long long a, long long b) { return a / b; }
#endif

/* --- <stdarg.h> */

#ifdef __GNUC__  /* !!! Also copy from __WATCOMC__ */
typedef char *va_list;  /* i386 only. */
#define va_start(ap, last) ap = ((char *)&(last)) + ((sizeof(last)+3)&~3)  /* i386 only. */
#define va_arg(ap, type) (ap += (sizeof(type)+3)&~3, *(type *)(ap - ((sizeof(type)+3)&~3)))  /* i386 only. */
#define va_copy(dest, src) (dest) = (src)  /* i386 only. */
#define va_end(ap)  /* i386 only. */
#endif

/* --- <ctype.h> */

extern int __LIBC_FUNC(isalpha, (int c));
extern int __LIBC_FUNC(isspace, (int c));
extern int __LIBC_FUNC(isdigit, (int c));
extern int __LIBC_FUNC(isxdigit, (int c));

/* --- <string.h> */

extern size_t __LIBC_FUNC(strlen, (const char *s));
extern char* __LIBC_FUNC(strcpy, (char *dest, const char *src));
extern int __LIBC_FUNC(strcmp, (const char *s1, const char *s2));
extern void* __LIBC_FUNC(memcpy, (void *dest, const void *src, size_t n));

/* --- <stdlib.h> */

extern void* __LIBC_FUNC(malloc, (size_t size));
extern __LIBC_NORETURN void __LIBC_FUNC(exit, (int status));

/* --- <fcntl.h> and <unistd.h> */
extern void* __LIBC_FUNC(sys_brk, (void *addr));
/**/
/* Check return value with `== -1' rather than `< 0' for Win32 portability. */
extern int __LIBC_FUNC(creat, (const char *pathname, mode_t mode));
/* Check return value with `== -1' rather than `< 0' for Win32 portability. */
extern int __LIBC_FUNC(open, (const char *pathname, int flags, mode_t mode));
extern int __LIBC_FUNC(close, (int fd));
/**/
extern ssize_t __LIBC_FUNC(read, (int fd, void *buf, size_t count));
extern ssize_t __LIBC_FUNC(write, (int fd, const void *buf, size_t count));
extern off_t __LIBC_FUNC(lseek, (int fd, off_t offset, int whence));
/**/
extern int __LIBC_FUNC(unlink, (const char *pathname));
extern int __LIBC_FUNC(remove, (const char *pathname));  /* Same as unlink(...). */
extern int __LIBC_FUNC(rename, (const char *oldpath, const char *newpath));
/**/
extern int __LIBC_FUNC(chdir, (const char *pathname));
extern int __LIBC_FUNC(mkdir, (const char *pathname, mode_t mode));
extern int __LIBC_FUNC(rmdir, (const char *pathname));
/**/
extern pid_t __LIBC_FUNC(getpid, (void));

#endif  /* If __LIBC_OK */
#endif  /* Ifndef _LIBC_H */
