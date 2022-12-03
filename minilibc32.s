/*
 * minilibc32.s: GNU as fork of minilibc32.nasm
 * by pts@fazekas.hu at Sun Nov 27 18:38:33 CET 2022
 *
 * Compile: as -32 -march=i386 -o minilibc32a.o minilibc32.s
 *
 * This source file was manually translated by minilibc32.nasm from NASM to
 * its current GNU as syntax, to be used on Linux i386 with GCC.
 * OpenWatcom C compiler is not supported, see minilibc32.nasm for that.
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

/* --- 64-bit integer multiplication, division and modulo. */

.globl __divdi3  /* regparm(3). */
.type  __divdi3, @function
__divdi3:
		push %ebp
		mov %esp, %ebp
		push 0xc(%ebp)
		push 0x8(%ebp)
		push %edx
		push %eax
		call __divdi3__RP0__
		leave
		ret

.globl __divdi3
.type  __divdi3, @function
__divdi3__RP0__:  /* No __RP3__ suffix. */
		push   %ebp
		mov    %esp,%ebp
		push   %edi
		push   %esi
		sub    $0x30,%esp
		mov    0xc(%ebp),%edx
		mov    0x8(%ebp),%eax
		mov    0x10(%ebp),%esi
		mov    0x14(%ebp),%edi
		mov    %edx,-0x24(%ebp)
		mov    -0x24(%ebp),%ecx
		mov    %eax,-0x28(%ebp)
		mov    %esi,%eax
		movl   $0x0,-0x30(%ebp)
		mov    %edi,%edx
		movl   $0x0,-0x2c(%ebp)
		test   %ecx,%ecx
		movl   $0x0,-0x1c(%ebp)
		js     .L1143
.L13e:		test   %edi,%edi
		js     .L1130
.L146:		mov    %edx,%edi
		mov    %eax,%esi
		mov    -0x28(%ebp),%edx
		mov    %eax,%ecx
		mov    -0x24(%ebp),%eax
		test   %edi,%edi
		mov    %edx,-0x10(%ebp)
		mov    %eax,-0x14(%ebp)
		jne    .L180
		cmp    %eax,%esi
		ja     .L1b1
		test   %esi,%esi
		je     .L1180
.L168:		mov    -0x14(%ebp),%eax
		mov    %edi,%edx
		div    %ecx
		mov    %eax,%esi
		mov    -0x10(%ebp),%eax
		div    %ecx
		mov    %eax,%ecx
		mov    %esi,%eax
		jmp    .L190
.L180:		cmp    -0x14(%ebp),%edi
		jbe    .L1c0
.L185:		xor    %ecx,%ecx
		xor    %eax,%eax
.L190:		mov    %ecx,-0x30(%ebp)
		mov    -0x1c(%ebp),%ecx
		mov    %eax,-0x2c(%ebp)
		mov    -0x30(%ebp),%eax
		mov    -0x2c(%ebp),%edx
		test   %ecx,%ecx
		je     .L1aa
		neg    %eax
		adc    $0x0,%edx
		neg    %edx
.L1aa:		add    $0x30,%esp
		pop    %esi
		pop    %edi
		pop    %ebp
		ret
.L1b1:		mov    %edx,%eax
		mov    -0x14(%ebp),%edx
		div    %esi
		mov    %eax,%ecx
		xor    %eax,%eax
		jmp    .L190
		mov    %esi,%esi
.L1c0:		bsr    %edi,%eax
		xor    $0x1f,%eax
		mov    %eax,-0x18(%ebp)
		je     .L1160
		mov    -0x18(%ebp),%edx
		mov    $0x20,%eax
		movzbl -0x18(%ebp),%ecx
		sub    %edx,%eax
		mov    %edi,%edx
		mov    %eax,-0xc(%ebp)
		shl    %cl,%edx
		mov    %esi,%eax
		movzbl -0xc(%ebp),%ecx
		mov    %edx,%edi
		mov    -0x10(%ebp),%edx
		shr    %cl,%eax
		movzbl -0x18(%ebp),%ecx
		or     %eax,%edi
		mov    -0x14(%ebp),%eax
		shl    %cl,%esi
		shl    %cl,%eax
		movzbl -0xc(%ebp),%ecx
		shr    %cl,%edx
		or     %edx,%eax
		mov    -0x14(%ebp),%edx
		mov    %eax,-0x34(%ebp)
		shr    %cl,%edx
		div    %edi
.L1110:		mov    %edx,-0x34(%ebp)
		mov    %eax,-0x38(%ebp)
		mul    %esi
		cmp    %edx,-0x34(%ebp)
		mov    %eax,%edi
		jb     .L119d
		je     .L1190
.L1121:		mov    -0x38(%ebp),%ecx
		xor    %eax,%eax
		jmp    .L190
.L1130:		mov    %esi,%eax
		mov    %edi,%edx
		neg    %eax
		adc    $0x0,%edx
.L1139:		neg    %edx
		notl   -0x1c(%ebp)
		jmp    .L146
.L1143:		negl   -0x28(%ebp)
		movl   $0xffffffff,-0x1c(%ebp)
		adcl   $0x0,-0x24(%ebp)
		negl   -0x24(%ebp)
		jmp    .L13e
.L1160:		cmp    -0x14(%ebp),%edi
		jb     .L116e
		cmp    -0x10(%ebp),%esi
		ja     .L185
.L116e:		mov    $0x1,%ecx
		xor    %eax,%eax
		jmp    .L190
.L1180:		mov    $0x1,%eax
		xor    %edx,%edx
		div    %esi
		mov    %eax,%ecx
		jmp    .L168
.L1190:		mov    -0x10(%ebp),%eax
		movzbl -0x18(%ebp),%ecx
		shl    %cl,%eax
		cmp    %edi,%eax
		jae    .L1121
.L119d:		mov    -0x38(%ebp),%ecx
		xor    %eax,%eax
		dec    %ecx
		jmp    .L190

.globl __udivdi3  /* regparm(3). */
.type  __udivdi3, @function
__udivdi3:
		push %ebp
		mov %esp, %ebp
		push 0xc(%ebp)
		push 0x8(%ebp)
		push %edx
		push %eax
		call __udivdi3__RP0__
		leave
		ret

.globl __udivdi3__RP0__
.type  __udivdi3__RP0__, @function
__udivdi3__RP0__:  /* No __RP3__ suffix. */
		push   %ebp
		mov    %esp,%ebp
		push   %edi
		push   %esi
		sub    $0x28,%esp
		mov    0x10(%ebp),%eax
		mov    0x14(%ebp),%edx
		movl   $0x0,-0x28(%ebp)
		movl   $0x0,-0x24(%ebp)
		mov    %eax,-0xc(%ebp)
		mov    %eax,%ecx
		mov    0x8(%ebp),%eax
		mov    %edx,%edi
		mov    0xc(%ebp),%edx
		test   %edi,%edi
		mov    %eax,-0x14(%ebp)
		mov    %edx,-0x18(%ebp)
		jne    .L263
		cmp    %edx,%ecx
		jbe    .L2d5
		div    %ecx
		mov    %eax,%ecx
		xor    %eax,%eax
.L250:		mov    %eax,-0x24(%ebp)
		mov    %ecx,-0x28(%ebp)
		mov    -0x24(%ebp),%edx
		mov    -0x28(%ebp),%eax
		add    $0x28,%esp
		pop    %esi
		pop    %edi
		pop    %ebp
		ret
.L263:		cmp    -0x18(%ebp),%edi
		ja     .L2100
		bsr    %edi,%eax
		xor    $0x1f,%eax
		mov    %eax,-0x1c(%ebp)
		je     .L2f3
		mov    -0x1c(%ebp),%edx
		mov    $0x20,%eax
		movzbl -0x1c(%ebp),%ecx
		mov    -0xc(%ebp),%esi
		sub    %edx,%eax
		mov    %edi,%edx
		mov    %eax,-0x10(%ebp)
		shl    %cl,%edx
		mov    -0xc(%ebp),%eax
		movzbl -0x10(%ebp),%ecx
		mov    %edx,%edi
		mov    -0x14(%ebp),%edx
		shr    %cl,%eax
		movzbl -0x1c(%ebp),%ecx
		or     %eax,%edi
		mov    -0x18(%ebp),%eax
		shl    %cl,%esi
		shl    %cl,%eax
.L2aa:		movzbl -0x10(%ebp),%ecx
		shr    %cl,%edx
		or     %edx,%eax
		mov    -0x18(%ebp),%edx
		mov    %eax,-0x2c(%ebp)
		shr    %cl,%edx
		div    %edi
		mov    %edx,%edi
		mov    %eax,-0x30(%ebp)
		mul    %esi
		cmp    %edx,%edi
		mov    %eax,%esi
		jb     .L2139
		je     .L212c
.L2cb:		mov    -0x30(%ebp),%ecx
		xor    %eax,%eax
		jmp    .L250
.L2d5:		mov    -0xc(%ebp),%esi
		test   %esi,%esi
		je     .L2110
.L2dc:		mov    -0x18(%ebp),%eax
		mov    %edi,%edx
		div    %ecx
		mov    %eax,%esi
		mov    -0x14(%ebp),%eax
		div    %ecx
		mov    %eax,%ecx
		mov    %esi,%eax
		jmp    .L250
.L2f3:		cmp    -0x18(%ebp),%edi
		jb     .L2120
		mov    -0x14(%ebp),%edx
		cmp    %edx,-0xc(%ebp)
		jbe    .L2120
.L2100:		xor    %ecx,%ecx
		xor    %eax,%eax
		jmp    .L250
.L2110:		mov    $0x1,%eax
		xor    %edx,%edx
		divl   -0xc(%ebp)
		mov    %eax,%ecx
		jmp    .L2dc
		mov    %esi,%esi
.L2120:		mov    $0x1,%ecx
		xor    %eax,%eax
		jmp    .L250
.L212c:		mov    -0x14(%ebp),%eax
		movzbl -0x1c(%ebp),%ecx
		shl    %cl,%eax
		cmp    %esi,%eax
		jae    .L2cb
.L2139:		mov    -0x30(%ebp),%ecx
		xor    %eax,%eax
		dec    %ecx
		jmp    .L250

.globl __moddi3  /* regparm(3). */
.type  __moddi3, @function
__moddi3:
		push %ebp
		mov %esp, %ebp
		push 0xc(%ebp)
		push 0x8(%ebp)
		push %edx
		push %eax
		call __moddi3__RP0__
		leave
		ret

.globl __moddi3__RP0__
.type  __moddi3__RP0__, @function
__moddi3__RP0__:  /* No __RP3__ suffix. */
		push   %ebp
		mov    %esp,%ebp
		push   %edi
		push   %esi
		sub    $0x50,%esp
		mov    0xc(%ebp),%edi
		mov    0x10(%ebp),%eax
		mov    0x14(%ebp),%edx
		movl   $0x0,-0x48(%ebp)
		mov    0x8(%ebp),%esi
		test   %edi,%edi
		movl   $0x0,-0x44(%ebp)
		mov    %eax,-0x50(%ebp)
		mov    %edx,-0x4c(%ebp)
		movl   $0x0,-0x3c(%ebp)
		js     .L31a2
.L337:		mov    -0x4c(%ebp),%ecx
		test   %ecx,%ecx
		js     .L3190
.L342:		lea    -0x10(%ebp),%ecx
		test   %edx,%edx
		mov    %ecx,-0x24(%ebp)
		mov    %eax,%ecx
		mov    %eax,-0x28(%ebp)
		mov    %edx,-0x2c(%ebp)
		mov    %esi,-0x20(%ebp)
		mov    %edi,-0x34(%ebp)
		jne    .L382
		cmp    %edi,%eax
		mov    %edi,%edx
		jbe    .L3170
		mov    %esi,%eax
		div    %ecx
.L368:		mov    %edx,-0x48(%ebp)
		movl   $0x0,-0x44(%ebp)
.L372:		mov    -0x24(%ebp),%ecx
		mov    -0x48(%ebp),%eax
		mov    -0x44(%ebp),%edx
		mov    %eax,(%ecx)
		mov    %edx,0x4(%ecx)
		jmp    .L3a0
.L382:		mov    -0x34(%ebp),%eax
		cmp    %eax,-0x2c(%ebp)
		jbe    .L3c0
		mov    %esi,-0x48(%ebp)
		mov    %edi,-0x44(%ebp)
		mov    -0x48(%ebp),%edx
		mov    -0x44(%ebp),%ecx
		mov    %edx,-0x10(%ebp)
		mov    %ecx,-0xc(%ebp)
.L3a0:		mov    -0x3c(%ebp),%eax
		test   %eax,%eax
		je     .L3b1
		negl   -0x10(%ebp)
		adcl   $0x0,-0xc(%ebp)
		negl   -0xc(%ebp)
.L3b1:		mov    -0x10(%ebp),%eax
		mov    -0xc(%ebp),%edx
		add    $0x50,%esp
		pop    %esi
		pop    %edi
		pop    %ebp
		ret
		mov    %esi,%esi
.L3c0:		bsr    -0x2c(%ebp),%eax
		xor    $0x1f,%eax
		mov    %eax,-0x38(%ebp)
		je     .L31c3
		mov    -0x38(%ebp),%edx
		mov    $0x20,%eax
		movzbl -0x38(%ebp),%ecx
		mov    -0x28(%ebp),%esi
		mov    -0x20(%ebp),%edi
		sub    %edx,%eax
		mov    -0x2c(%ebp),%edx
		mov    %eax,-0x30(%ebp)
		mov    -0x28(%ebp),%eax
		shl    %cl,%edx
		movzbl -0x30(%ebp),%ecx
		shr    %cl,%eax
		movzbl -0x38(%ebp),%ecx
		or     %eax,%edx
		mov    -0x34(%ebp),%eax
		mov    %edx,-0x1c(%ebp)
		mov    -0x20(%ebp),%edx
		shl    %cl,%esi
		shl    %cl,%eax
		movzbl -0x30(%ebp),%ecx
		shr    %cl,%edx
		movzbl -0x38(%ebp),%ecx
		or     %edx,%eax
		mov    -0x34(%ebp),%edx
		shl    %cl,%edi
		movzbl -0x30(%ebp),%ecx
		shr    %cl,%edx
		divl   -0x1c(%ebp)
		mov    %edx,-0x54(%ebp)
		mul    %esi
		cmp    %edx,-0x54(%ebp)
		jb     .L320d
		je     .L3205
.L3136:		mov    -0x54(%ebp),%ecx
		sub    %eax,%edi
		sbb    %edx,%ecx
		mov    %ecx,-0x54(%ebp)
		mov    %ecx,%edx
		movzbl -0x30(%ebp),%ecx
		mov    %edi,%eax
		shl    %cl,%edx
		movzbl -0x38(%ebp),%ecx
		shr    %cl,%eax
		or     %eax,%edx
		mov    -0x54(%ebp),%eax
		mov    %edx,-0x48(%ebp)
		mov    -0x48(%ebp),%edx
		shr    %cl,%eax
		mov    %eax,-0x44(%ebp)
		mov    -0x24(%ebp),%eax
		mov    -0x44(%ebp),%ecx
		mov    %edx,(%eax)
		mov    %ecx,0x4(%eax)
		jmp    .L3a0
.L3170:		mov    -0x28(%ebp),%esi
		test   %esi,%esi
		je     .L31b5
.L3177:		mov    -0x34(%ebp),%eax
		mov    -0x2c(%ebp),%edx
		div    %ecx
		mov    -0x20(%ebp),%eax
		div    %ecx
		jmp    .L368
.L3190:		mov    -0x50(%ebp),%eax
		mov    -0x4c(%ebp),%edx
		neg    %eax
		adc    $0x0,%edx
		neg    %edx
		jmp    .L342
.L31a2:		neg    %esi
		adc    $0x0,%edi
		neg    %edi
		movl   $0xffffffff,-0x3c(%ebp)
		jmp    .L337
.L31b5:		mov    $0x1,%eax
		xor    %edx,%edx
		divl   -0x28(%ebp)
		mov    %eax,%ecx
		jmp    .L3177
.L31c3:		mov    -0x34(%ebp),%ecx
		cmp    %ecx,-0x2c(%ebp)
		jb     .L31f1
		mov    -0x20(%ebp),%eax
		cmp    %eax,-0x28(%ebp)
		jbe    .L31f1
.L31e0:		mov    -0x20(%ebp),%eax
		mov    -0x34(%ebp),%edx
		mov    %eax,-0x48(%ebp)
		mov    %edx,-0x44(%ebp)
		jmp    .L372
.L31f1:		mov    -0x34(%ebp),%edx
		mov    -0x20(%ebp),%ecx
		sub    -0x28(%ebp),%ecx
		sbb    -0x2c(%ebp),%edx
		mov    %ecx,-0x20(%ebp)
		mov    %edx,-0x34(%ebp)
		jmp    .L31e0
.L3205:		cmp    %eax,%edi
		jae    .L3136
.L320d:		sub    %esi,%eax
		sbb    -0x1c(%ebp),%edx
		jmp    .L3136

.globl __umoddi3  /* regparm(3). */
.type  __umoddi3, @function
__umoddi3:
		push %ebp
		mov %esp, %ebp
		push 0xc(%ebp)
		push 0x8(%ebp)
		push %edx
		push %eax
		call __umoddi3__RP0__
		leave
		ret

.globl __umoddi3__RP0__
.type  __umoddi3__RP0__, @function
__umoddi3__RP0__:  /* No __RP3__ suffix. */
		push   %ebp
		mov    %esp,%ebp
		push   %edi
		push   %esi
		sub    $0x30,%esp
		mov    0x14(%ebp),%edx
		mov    0x10(%ebp),%eax
		mov    0x8(%ebp),%esi
		mov    0xc(%ebp),%edi
		test   %edx,%edx
		movl   $0x0,-0x30(%ebp)
		mov    %eax,%ecx
		movl   $0x0,-0x2c(%ebp)
		mov    %eax,-0x14(%ebp)
		mov    %edx,-0x18(%ebp)
		mov    %esi,-0x10(%ebp)
		mov    %edi,-0x20(%ebp)
		jne    .L460
		cmp    %edi,%eax
		mov    %edi,%edx
		jbe    .L4130
		mov    %esi,%eax
		div    %ecx
.L442:		mov    %edx,-0x30(%ebp)
		movl   $0x0,-0x2c(%ebp)
		mov    -0x30(%ebp),%eax
		mov    -0x2c(%ebp),%edx
		add    $0x30,%esp
		pop    %esi
		pop    %edi
		pop    %ebp
		ret
.L460:		mov    -0x20(%ebp),%ecx
		cmp    %ecx,-0x18(%ebp)
		jbe    .L480
		mov    %esi,-0x30(%ebp)
		mov    %edi,-0x2c(%ebp)
		mov    -0x30(%ebp),%eax
		mov    -0x2c(%ebp),%edx
		add    $0x30,%esp
		pop    %esi
		pop    %edi
		pop    %ebp
		ret
.L480:		bsr    -0x18(%ebp),%eax
		xor    $0x1f,%eax
		mov    %eax,-0x24(%ebp)
		je     .L4160
		mov    -0x24(%ebp),%edx
		mov    $0x20,%eax
		movzbl -0x24(%ebp),%ecx
		mov    -0x14(%ebp),%esi
		mov    -0x10(%ebp),%edi
		sub    %edx,%eax
		mov    -0x18(%ebp),%edx
		mov    %eax,-0x1c(%ebp)
		mov    -0x14(%ebp),%eax
		shl    %cl,%edx
		movzbl -0x1c(%ebp),%ecx
		shr    %cl,%eax
		movzbl -0x24(%ebp),%ecx
		or     %eax,%edx
		mov    -0x20(%ebp),%eax
		mov    %edx,-0xc(%ebp)
		mov    -0x10(%ebp),%edx
		shl    %cl,%esi
		shl    %cl,%eax
		movzbl -0x1c(%ebp),%ecx
		shr    %cl,%edx
		movzbl -0x24(%ebp),%ecx
		or     %edx,%eax
		mov    -0x20(%ebp),%edx
		shl    %cl,%edi
		movzbl -0x1c(%ebp),%ecx
		shr    %cl,%edx
		divl   -0xc(%ebp)
		mov    %edx,-0x34(%ebp)
		mul    %esi
		cmp    %edx,-0x34(%ebp)
		jb     .L41a5
		je     .L419d
.L4f6:		mov    -0x34(%ebp),%ecx
		sub    %eax,%edi
		sbb    %edx,%ecx
		mov    %ecx,-0x34(%ebp)
		mov    %ecx,%edx
		movzbl -0x1c(%ebp),%ecx
		mov    %edi,%eax
		shl    %cl,%edx
		movzbl -0x24(%ebp),%ecx
		shr    %cl,%eax
		or     %eax,%edx
		mov    -0x34(%ebp),%eax
		mov    %edx,-0x30(%ebp)
		shr    %cl,%eax
		mov    %eax,-0x2c(%ebp)
		mov    -0x30(%ebp),%eax
		mov    -0x2c(%ebp),%edx
		add    $0x30,%esp
		pop    %esi
		pop    %edi
		pop    %ebp
		ret
.L4130:		mov    -0x14(%ebp),%esi
		test   %esi,%esi
		je     .L4150
.L4137:		mov    -0x20(%ebp),%eax
		mov    -0x18(%ebp),%edx
		div    %ecx
		mov    -0x10(%ebp),%eax
		div    %ecx
		jmp    .L442
.L4150:		mov    $0x1,%eax
		xor    %edx,%edx
		divl   -0x14(%ebp)
		mov    %eax,%ecx
		jmp    .L4137
		mov    %esi,%esi
.L4160:		mov    -0x20(%ebp),%eax
		cmp    %eax,-0x18(%ebp)
		jb     .L4189
		mov    -0x10(%ebp),%edx
		cmp    %edx,-0x14(%ebp)
		jbe    .L4189
.L4170:		mov    -0x10(%ebp),%edx
		mov    -0x20(%ebp),%ecx
		mov    %edx,-0x30(%ebp)
		mov    %ecx,-0x2c(%ebp)
		mov    -0x30(%ebp),%eax
		mov    -0x2c(%ebp),%edx
		add    $0x30,%esp
		pop    %esi
		pop    %edi
		pop    %ebp
		ret
.L4189:		mov    -0x20(%ebp),%ecx
		mov    -0x10(%ebp),%eax
		sub    -0x14(%ebp),%eax
		sbb    -0x18(%ebp),%ecx
		mov    %eax,-0x10(%ebp)
		mov    %ecx,-0x20(%ebp)
		jmp    .L4170
.L419d:		cmp    %eax,%edi
		jae    .L4f6
.L41a5:		sub    %esi,%eax
		sbb    -0xc(%ebp),%edx
		jmp    .L4f6

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
