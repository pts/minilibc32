minilibc32: size-optimized, minimalistic libc for Linux i386
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
minilibc32 is an size-optimized and minimalistic libc (C
runtime library) for writing programs in C targeting Linux i386 (executable
program file format ELF32) compiled with the OpenWatcom C compiler or GCC.
Size-optimized means that the library functions are written by hand in
assembly language, favoring shorter code size over execution speed.

To try minilibc32 on Linux, install OpenWatcom, GCC, NASM, sstrip
(https://github.com/BR903/ELFkickers/blob/master/sstrip/sstrip.c), and run
`./compile.sh' from the cloned Git working directory. The libc machine code
is in the created minilibc32*.o files (for GCC and TCC (TinyCC)), in
minilibc32*.obj files (for the OpenWatcom C compiler) and in the
minilibc32.bin file (for size comparisons), and the test programs (Linux
i386 ELF32 executable programs) are in the files test*ow and test*gc.

For production use, one of OpenWatcom or GCC (not both) will be enough. TCC
also works, but it generates verbose code, defeating the size optimization
purpose of minilibc32.

Compilation command lines of the hello-world test program:

  $ gcc -static -s -D__LIBC_OMIT_ABITEST_DIVDI3 -nostdlib -nostdinc -Os -m32 -Wl,-z,norelro -Wl,--build-id=none -mno-align-stringops -mregparm=3 -fno-pic -fno-stack-protector -fomit-frame-pointer -fno-ident -ffreestanding -fno-builtin -fno-unwind-tables -fno-asynchronous-unwind-tables -falign-functions=1 -mpreferred-stack-boundary=2 -falign-jumps=1 -falign-loops=1 -march=i386 -ansi -pedantic -W -Wall -Werror=implicit-function-declaration -o test_hello test_hello.c minilibc32.o
  $ owcc -s -blinux -fnostdlib -Os -fno-stack-check -march=i386 -W -Wall -Wextra -o test_hello test_hello.c minilibc32.obj
  $ tcc -s -static -O2 -W -Wall -nostdlib -nostdinc -o test_hello test_hello.c minilibc32.o

Then run it:

  $ ./test_hello; echo $?
  Hello, World!
  0

Please note that byte sizes of the generated executable program test_hello
is not very impressive, because the default linkers (of GCC, OpenWatcom and
TCC) add too much boilerplate, and also the unused libc functions are
included in the executable. This will be fixed eventually in a future
version by adding a custom linker which doesn't add unnecesary bytes. That
linker will also support the Win32 target.

Byte sizes of i386 machine code of some libc functions in minilibc32 using
the OpenWatcom __watcall calling convention:

* isalpha(3): 11 bytes
* isspace(3): 15 bytes
* isdigit(3): 9 bytes
* isxdigit(3): 17 bytes
* strlen(3): 14 bytes
* strcpy(3): 16 bytes
* strcmp(3): 26 bytes
* memcpy(3): 16 bytes
* alloca(3): 16 bytes
* malloc(3): 112 bytes, unaligned, uses brk(2), no way to free(3) heap memory
* _start entry point startup code calling main(...) + exit(2): 8 bytes
* syscall trampoline __do_syscall3(...): 19 bytes
* syscall (system call) wrappers (e.g. write(2)): 4 bytes each
* total of the above: 340 bytes

i386 means in this context means not only the 32-bit Intel x86 (IA-32)
instruction set architecture (ISA), but also the minimum CPU requirement
(Intel 80386). Newer 32-bit Intel CPU features (e.g. i686 standing for
Pentium Pro) are neither required or used.

minilibc32 is intentionally kept minimalistic, and it's unlikely that all
the larger functions (such as printf(3), scanf(3), buffered fwrite(3) and a
proper memory allocator) will be added soon. If you need more functionality
and you are targeting Linux i386, use pts-xtiny
(https://github.com/pts/pts-xtiny) instead. For even more functionality on
Linux i386, use pts-xstatic
(https://github.com/pts/pts-clang-xstatic/blob/master/README.pts-xstatic.txt)
instead.

Compared to pts-xtiny and pts-xstatic, minilibc32 contains much less
functionality, but the functionality it actually contains is much better
size-optimized. As soon as the custom linker is written for minilibc32,
generated executable programs will be smaller than with pts-xtiny and
pts-xstatic.

With minilibc32 it's not yet possible to create small Linux i386 ELF
exeutable programs, because (1) all the library (321 bytes) has to be
linked, not only the used functions; (2) the OpenWatcom ELF32 linker adds
about 4 KiB of padding between the .text and .data sections, making these
programs way too large. However, based on the filesz output of `objdump -x
test_hello.ow', the minimum ELF32 hello-world program would be:

* ELF32 header (.ehdr): 52 bytes
* ELF32 program header (.phdr) consisting of .text and .data: 64 bytes
* .text section: 60 bytes
* .data section: 15 bytes ("Hello, World!\n" with a trailing NUL).
* total: 191 bytes

This is not an absolute minimum for a hello-world benchmark, because it's
possible to merge .text and .data to a single section, and it's possible to
omit the trailing NUL from the message, and by writing everything in assembly
(the main(...) function is currently in C) it's possible to remove some more
bytes by better register usage. See the classic piece
https://www.muppetlabs.com/~breadbox/software/tiny/teensy.html on writing
everything (including the ELF32 header) in NASM assembly language.

Here is the annotated disassembly of the code (.text section) only of the
hello-world benchmark (60 bytes):

  main_:  ; __watcall calling convention.
  08048100  53                push ebx
  08048101  BB0E000000        mov ebx, 0xe  ; Message size in bytes.
  08048106  BA00900408        mov edx, 0x8049000  ; "Hello, World!\n" message.
  0804810B  B802000000        mov eax, 0x1  ; STDOUT_FILENO.
  08048110  E804000000        call 0x8048119  ; write_.
  08048115  31C0              xor eax, eax
  08048117  5B                pop ebx
  08048118  C3                ret

  write_:  ; __watcall calling convention.
  08048119  6A04              push byte +0x4  ; __NR_write.
  0804811B  EB0A              jmp short 0x8048127  ; __do_syscall3.

  _start:  ; ELF program entry point with Linux i386 ELF System V ABI.
  0804811D  58                pop eax  ; argc by kernel on stack.
  0804811E  89E2              mov edx, esp  ; argv by kernel on stack.
  08048120  E8DBFFFFFF        call 0x8048100  ; main_.
                              ; Fall through to exit_, status in EAX.
  exit_:  ; __watcall calling convention.
  08048125  6A01              push byte +0x1  ; __NR_exit.
                              ; Fall through to __do_syscall3.
  __do_syscall3:  ; Call a Linux i386 syscall with up to 3 arguments.
  08048127  870C24            xchg ecx, [esp]  ; Syscall number on stack.
  0804812A  93                xchg eax, ebx  ; Shuffle arguments.
  0804812B  92                xchg eax, edx
  0804812C  91                xchg eax, ecx
  0804812D  52                push edx
  0804812E  53                push ebx
  0804812F  CD80              int 0x80  ; Syscall number in EAX.
  08048131  85C0              test eax, eax  ; Negative result is failure.
  08048133  7903              jns 0x8048138  ; __do_syscall3_ok
  08048135  83C8FF            or eax, byte -0x1
  __do_syscall3_ok:
  08048138  5B                pop ebx
  08048139  5A                pop edx
  0804813A  59                pop ecx
  0804813B  C3                ret  ; Return value in EAX.

__do_syscall3 looks suspiciously long above, but it has many 1-byte
instructions (so that's not so many bytes), and the instructions are needed
for shuffling the registers between calling conventions (__watcall vs Linux
i386 system call ABI).

Also note that for each new system call supported there is only 4 bytes
added to the libc code: `push byte +nr' and `jmp short __do_syscall3'.

minilibc32 was tested with GCC 4.8.4, GCC 6.3.0, GCC 7.5.0, TCC (TinyCC)
0.9.26, and various versions of OpenWatcom released in 2022.

Limitations and missing features from minilibc32:

* Currently the OpenWatcom C compiler, GCC and TCC are the only supported
  compilers. There are plans to add Clang support (which should be easy,
  it's similar enough to GCC).
* envp and environ are not populated, there is no way to get the
  environment variables from C.
* errno is not populated, there is no way to get syscall error numbers
  from C.
* Non-constant initializers (constructors and destructors) are not
  supported. All global variables must be initialized to a
  compile-or-link-time constant.
* If the program doesn't use all functions, the unused ones have to be
* Removed manually from this file; removal is hard for the syscalls and
  easy for others.
* Heap memory cannot be returned to the system, there is no free(...)
  corresponding to malloc(...).
* malloc(...) may allocate twice as much as necessary, to buffer.
* malloc(...) returns an unaligned pointer. This works on x86 (except for
  SIMD register moves), but it's slower than aligned.
* At the current scale it can support up to 29 Linux i386 system calls,
  all with system call number 0..127, all taking 0..3 arguments. That's
  because for each system call, there is a `push byte +nr' and a `jmp short
  __do_syscall3'.

__END__
