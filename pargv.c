/*
 * pargv.c: test program that prints the command-line arguments, line-by-line
 * by pts@fazekas.hu at Thu Dec  1 15:57:22 CET 2022
 *
 * Compile: gcc -s -O2 -W -Wall -ansi -pedantic -o pargv pargv.c
 * Compile: gcc -D__MINILIBC32__ -Wl,-z,norelro -Wl,--build-id=none -s -static -m32 -mregparm=3 -fno-pic -fno-stack-protector -fomit-frame-pointer -fno-ident -ffreestanding -fno-builtin -fno-unwind-tables -fno-asynchronous-unwind-tables -nostdlib -nostdinc -Os -falign-functions=1 -mpreferred-stack-boundary=2 -falign-jumps=1 -falign-loops=1 -march=i386 -ansi -pedantic -W -Wall -Werror=implicit-function-declaration -o pargv pargv.c minilibc32.o && sstrip pargv
 * Compile: owcc -bwin32 -Wl,runtime -Wl,console=3.10 -Os -s -fno-stack-check -march=i386 -W -Wall -Wextra -o pargv.exe pargv.c
 */

#if defined(__WATCOMC__) && defined(_WIN32) && defined(_M_I386)
   typedef unsigned        size_t;
   typedef int             ssize_t;
   typedef unsigned short  wchar_t;
   typedef char            CHAR;
   typedef unsigned int    UINT;
   typedef unsigned long   DWORD;
   typedef void           *HANDLE;
   typedef int             BOOL;
   typedef void           *LPVOID;
   typedef const void     *LPCVOID;
   typedef DWORD          *LPDWORD;
   typedef struct _OVERLAPPED *LPOVERLAPPED;
   typedef CHAR           *LPSTR;
   typedef wchar_t         WCHAR;
   typedef WCHAR          *LPWSTR;
   __declspec(aborts) __declspec(dllimport) void __stdcall ExitProcess(UINT uExitCode);
   __declspec(dllimport) HANDLE __stdcall GetStdHandle(DWORD nStdHandle);
   __declspec(dllimport) BOOL   __stdcall WriteFile(HANDLE hFile, LPCVOID lpBuffer, DWORD nNumberOfBytesToWrite, LPDWORD lpNumberOfBytesWritten, LPOVERLAPPED lpOverlapped);
   __declspec(dllimport) BOOL   __stdcall ReadFile(HANDLE hFile, LPVOID lpBuffer, DWORD nNumberOfBytesToRead, LPDWORD lpNumberOfBytesRead, LPOVERLAPPED lpOverlapped);
   __declspec(dllimport) LPSTR  __stdcall GetCommandLineA(void);
   __declspec(dllimport) LPWSTR __stdcall GetCommandLineW(void);
#  define NULL ((void *)0)
#  define STD_INPUT_HANDLE    ((DWORD)-10)
#  define STD_OUTPUT_HANDLE   ((DWORD)-11)
#  define STD_ERROR_HANDLE    ((DWORD)-12)
#  define STDOUTFD ((int)GetStdHandle(STD_OUTPUT_HANDLE))
   static ssize_t write(int fd, const void *buf, size_t count) {
     DWORD written_count;
     return WriteFile((HANDLE)fd, buf, count, &written_count, NULL) ? written_count : -1;
   }
   /* Overrides lib386/nt/clib3r.lib / mbcupper.o
    * Source: https://github.com/open-watcom/open-watcom-v2/blob/master/bld/clib/mbyte/c/mbcupper.c
    * Overridden implementation calls CharUpperA in USER32.DLL:
    * https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-charuppera
    *
    * This function is a transitive dependency of _cstart() with main() in
    * OpenWatcom. By overridding it, we remove the transitive dependency of all
    * .exe files compiled with `owcc -bwin32' on USER32.DLL.
    *
    * This is a simplified implementation, it keeps non-ASCII characters intact.
    */
   unsigned int _mbctoupper(unsigned int c) {
     return (c - 'a' + 0U <= 'z' - 'a' + 0U)  ? c + 'A' - 'a' : c;
   }
#else
#  ifdef __MINILIBC32__
#    include "libc.h"
#  else
#    include <unistd.h>
#  endif
   static const int STDOUTFD = 1;
#endif

static int my_strlen(const char *s) {
  const char *s0 = s;
  for (; *s != '\0'; ++s) {}
  return s - s0;
}

int main(int argc, char **argv) {
  const int fd = STDOUTFD;
  (void)argc;
  for (++argv; *argv; ++argv) {
    (void)!write(fd, *argv, my_strlen(*argv));
    (void)!write(fd, "\n", 1);
  }
  return 0;
}
