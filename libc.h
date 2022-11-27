/* by pts@fazekas.hu at Sun Nov 27 13:52:31 CET 2022 */

#ifndef _LIBC_H
#define _LIBC_H 1

#undef __LIBC_OK

#if defined(__WATCOMC__) && defined(_M_I386)
#  define __LIBC_OK 1
#else
#  error Unsupported libc target.
#endif
#ifndef __LIBC_OK
#  define __LIBC_OK 0
#endif
#if __LIBC_OK

#define main main_from_libc  /* TODO(pts): Rename at assembler level, add symbol alias here. For OpenWatcom. */
#define open libc_open  /* Avoid using the OpenWatcom C compiler using the `...' form. */

extern int __watcall main(int argc, char **argv);

#define NULL ((void*)0)

#define SEEK_SET 0  /* whence value below. */
#define SEEK_CUR 1
#define SEEK_END 2

#define O_RDONLY 0  /* flags bitfield value below. */
#define O_WRONLY 1
#define O_RDWR   2

#define STDIN_FILENO  0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2

#define EXIT_SUCCESS 0  /* status values below. Can be 0..255. */
#define EXIT_FAILURE 1

typedef unsigned size_t;
typedef int ssize_t;
typedef unsigned mode_t;
typedef long off_t;  /* Not implemented: 64-bit off_t (#define _FILE_OFFSET_BITS 64), off64_r, lseek64(2). */

extern ssize_t write(int fd, const void *buf, size_t count);

/* --- <ctype.h> */

extern int __watcall isalpha(int c);
extern int __watcall isspace(int c);
extern int __watcall isdigit(int c);
extern int __watcall isxdigit(int c);

/* --- <string.h> */

extern size_t __watcall strlen(const char *s);
extern char* __watcall strcpy(char *dest, const char *src);
extern int __watcall strcmp(const char *s1, const char *s2);
extern __declspec(aborts) void __watcall exit(int status);

/* --- <stdlib.h> */

extern void* __watcall malloc(size_t size);

/* --- <fcntl.h> and <unistd.h> */
extern void* __watcall sys_brk(void *addr);
/**/
extern int __watcall creat(const char *pathname, mode_t mode);
extern int __watcall open(const char *pathname, int flags, mode_t mode);
extern int __watcall close(int fd);
/**/
extern ssize_t __watcall read(int fd, void *buf, size_t count);
extern ssize_t __watcall write(int fd, const void *buf, size_t count);
extern off_t __watcall lseek(int fd, off_t offset, int whence);
/**/
extern int __watcall unlink(const char *pathname);
extern int __watcall remove(const char *pathname);  /* Same as unlink(...). */
extern int __watcall rename(const char *oldpath, const char *newpath);

#endif  /* If __LIBC_OK */
#endif  /* Ifndef _LIBC_H */
