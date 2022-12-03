/*
 * minilibc32.s: GNU as fork in minilibc32.nasm
 * by pts@fazekas.hu at Sun Nov 27 18:38:33 CET 2022
 *
 * Compile: as -32 -march=i386 -o minilibc32a.o minilibc32.s
 *
 * This source file was manually translated by minilibc32.nasm from NASM to
 * its current GNU as syntax, to be used on Linux i386 with GCC.
 *
 * GNU as is smart enough to encode the shorter (2-byte) versions of `push'
 * and `jmp' if the constants are small.
 */

.text

/* Labels starting with .L aren't saved by GNU as to the .o file. GCC
 * generates labels with .L<num>, we generate .LA<num> to avoid conflicts
 * in case this file is conatenated to an .s file emitted by `gcc -S'.
 */

.globl isalpha__RP3__
.type  isalpha__RP3__, @function
isalpha__RP3__:
		or $0x20, %al
		sub $0x61, %al
		cmp $0x1a, %al
		sbb %eax, %eax
		neg %eax
		ret

.globl isspace__RP3__
.type  isspace__RP3__, @function
isspace__RP3__:
		sub $9, %al
		cmp $5, %al
		jb .LA1
		sub $0x17, %al
		cmp $1, %al
.LA1:		sbb %eax, %eax
		neg %eax
		ret

.globl isdigit__RP3__
.type  isdigit__RP3__, @function
isdigit__RP3__:
		sub $0x30, %al
		cmp $0x0a, %al
		sbb %eax, %eax
		neg %eax
		ret

.globl isxdigit__RP3__
.type  isxdigit__RP3__, @function
isxdigit__RP3__:
		sub $0x30, %al
		cmp $0x0a, %al
		jb .LA2
		or $0x20, %al
		sub $0x31, %al
		cmp $6, %al
.LA2:		sbb %eax, %eax
		neg %eax
		ret

.globl strlen__RP3__
.type  strlen__RP3__, @function
strlen__RP3__:
		push %esi
		xchg %esi, %eax
		xor %eax, %eax
		dec %eax
.LA3:		cmpb $1, (%esi)
		inc %esi
		inc %eax
		jae .LA3
		pop %esi
		ret

.globl strcpy__RP3__
.type  strcpy__RP3__, @function
strcpy__RP3__:
		push %edi
		xchg %edx, %esi
		xchg %edi, %eax
		push %edi
.LA4:		lodsb
		stosb
		cmp $0, %al
		jne .LA4
		pop %eax
		xchg %edx, %esi
		pop %edi
		ret

.globl strcmp__RP3__
.type  strcmp__RP3__, @function
strcmp__RP3__:
		push %esi
		xchg %esi, %eax
		xor %eax, %eax
		xchg %edx, %edi
.LA5:		lodsb
		scasb
		jne .LA6
		cmp $0, %al
		jne .LA5
		jmp .LA7
.LA6:		mov $1, %al
		jae .LA7
		neg %eax
.LA7:		xchg %edx, %edi
		pop %esi
		ret

.globl memcpy__RP3__
.type  memcpy__RP3__, @function
memcpy__RP3__:
		push %edi
		xchg %edx, %esi
		xchg %eax, %edi
		push %edi
		rep movsb
		pop %eax
		xchg %edx, %esi
		pop %edi
		ret

.globl sys_brk__RP3__
.type  sys_brk__RP3__, @function
sys_brk__RP3__:
		push $45
		jmp __do_syscall3

.globl unlink__RP3__
.type  unlink__RP3__, @function
unlink__RP3__:

.globl remove__RP3__
.type  remove__RP3__, @function
remove__RP3__:
		push $10
		jmp __do_syscall3

.globl close__RP3__
.type  close__RP3__, @function
close__RP3__:
		push $6
		jmp __do_syscall3

.globl creat__RP3__
.type  creat__RP3__, @function
creat__RP3__:
		push $8
		jmp __do_syscall3

.globl rename__RP3__
.type  rename__RP3__, @function
rename__RP3__:
		push $38
		jmp __do_syscall3

.globl open__RP3__
.type  open__RP3__, @function
open__RP3__:

.globl open3__RP3__
.type  open3__RP3__, @function
open3__RP3__:
		push $5
		jmp __do_syscall3

.globl read__RP3__
.type  read__RP3__, @function
read__RP3__:
		push $3
		jmp __do_syscall3

.globl lseek__RP3__
.type  lseek__RP3__, @function
lseek__RP3__:
		push $19
		jmp __do_syscall3

.globl chdir__RP3__
.type  chdir__RP3__, @function
chdir__RP3__:
		push $12
		jmp __do_syscall3

.globl mkdir__RP3__
.type  mkdir__RP3__, @function
mkdir__RP3__:
		push $39
		jmp __do_syscall3

.globl rmdir__RP3__
.type  rmdir__RP3__, @function
rmdir__RP3__:
		push $40
		jmp __do_syscall3

.globl getpid__RP3__
.type  getpid__RP3__, @function
getpid__RP3__:
		push $20
		jmp __do_syscall3

.globl write__RP3__
.type  write__RP3__, @function
write__RP3__:
		push $4
		jmp __do_syscall3

.globl _start
.type  _start, @function
_start:
		pop %eax
		mov %esp, %edx
		push %edx
		push %eax
.extern main  /* Optional. */
		call main
/* Fall through to exit(...). */

.globl exit__RP3__
.type  exit__RP3__, @function
exit__RP3__:
		push $1
__do_syscall3:
		xchg (%esp), %ebx
		xchg %ebx, %eax
		xchg %edx, %ecx
		push %edx
		push %ecx
		int $0x80
		test %eax, %eax
		jns .LA8
		or $-1, %eax
.LA8:		pop %ecx
		pop %edx
		pop %ebx
		ret

/* --- BSS. */

/* Not needed. It would be needed by malloc(...). */
/*
.comm __malloc_base, 4, 4
.comm __malloc_free, 4, 4
.comm __malloc_end,  4, 4
*/
/* !! TODO(pts): Why does the final program file become 440 bytes longer if we omit at least 1 of these 3 variables? */
.comm __dummy1, 4, 4
.comm __dummy2, 4, 4
.comm __dummy3, 4, 4
/**/

/* Disable code execution in stack.*/
/* .section .note.GNU-stack,"",@progbits */
