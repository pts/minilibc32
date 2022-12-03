;
; minilibc32.nasm: size-optimized minimalistic libc for Linux i386
; by pts@fazekas.hu at Sun Nov 27 03:25:15 CET 2022
;
; Compile for OpenWatcom: nasm-0.98.39 -O9 -f obj -o minilibc32.obj minilibc32.nasm
;
; Compile for GCC: nasm-0.98.39 -O9 -f elf -o minilibc32.o minilibc32.nasm
;
; Test compile for size only: nasm-0.98.39 -O9 -f bin -o minilibc32.bin minilibc32.nasm
;
; Functions in this libc are optimized for code size rather than execution
; speed.
;
; All labels whose name ends with _ are functions with the __watcall calling
; convention. TODO(pts): Add alternative libc for `gcc -mregparm=3'.
;
; The __watcall calling convention of OpenWatcom passes function arguments
; in EAX, EDX, EBX, ECX, and expects the return value in EAX. The callee may
; use EAX, the arithmetic flags in EFLAGS (but not DF, which is expected to
; be 0 and must restored to 0) and all actual argument registers are scratch
; registers, and it must restore everything else.
;
; The regparm(3) calling convention of GCC passes up to 3 function arguments
; in EAX, EDX, ECX (please note that ECX is different from __watcall), and
; pushes the rest to the stack ([esp+4], [esp+8] etc.; [esp] is the return
; address). The caller removes arguments from the stack.
;
; TODO(pts): Convert this NASM source to WASM and GNU as, and drop NASM as a
;     dependency. This is not a good idea (to drop), because NASM can link a
;     smaller executable program.
; TODO(pts): Add `long long' multiplication and division functions, for GCC
;     and OpenWatcom.
;

		bits 32
		cpu 386

%ifidn __OUTPUT_FORMAT__,obj  ; OpenWatcom segments.
		section _TEXT  USE32 class=CODE align=1
		section CONST  USE32 class=DATA align=1  ; OpenWatcom generates align=4.
		section CONST2 USE32 class=DATA align=4
		section _DATA  USE32 class=DATA align=4
		section _BSS   USE32 class=BSS NOBITS align=4  ; NOBITS is ignored by NASM, but class=BSS works.
		group DGROUP CONST CONST2 _DATA _BSS
		section _TEXT
%else
		section .bss align=4
		section .text align=1
		section .text
%define _BSS .bss  ; Section name.
%endif

%ifidn __OUTPUT_FORMAT__,elf  ; GCC regparm(3) calling convention.
%define SYM(name) name %+ __RP3__  ; GCC regparm(3) calling convention is indicated for minilibc32 GCC.
%define REGARG3 ecx
%define REGNARG ebx  ; A register which is not used by the first 3 function arguments.
%else  ; OpenWatcom __watcall calling convention.
%define SYM(name) name %+ _  ; OpenWatcom __watcall calling convention is indicated with a trailing `_' by OpenWatcom.
%define REGARG3 ebx
%define REGNARG ecx
%endif

; --- Generic i386 functions.

%ifndef FEATURES_WE  ; FEATURES_WE means write(...) + exit(...) only, for hello-world benchmark.

global SYM($isalpha)
SYM($isalpha):
		or al, 20h
		sub al, 61h
		cmp al, 1ah
		sbb eax, eax
		neg eax
		ret

global SYM($isspace)
SYM($isspace):
		sub al, 9
		cmp al, 5
		jb .1
		sub al, 17h
		cmp al, 1
.1:		sbb eax, eax
		neg eax
		ret

global SYM($isdigit)
SYM($isdigit):
		sub al, 30h
		cmp al, 0ah
		sbb eax, eax
		neg eax
		ret

global SYM($isxdigit)
SYM($isxdigit):
		sub al, 30h
		cmp al, 0ah
		jb .2
		or al, 20h
		sub al, 31h
		cmp al, 6
.2:		sbb eax, eax
		neg eax
		ret

global SYM($strlen)
SYM($strlen):
		push esi
		xchg eax, esi
		xor eax, eax
		dec eax
.3:		cmp byte [esi], 1
		inc esi
		inc eax
		jae .3
		pop esi
		ret

global SYM($strcpy)
SYM($strcpy):
		push edi
		xchg esi, edx
		xchg eax, edi
		push edi
.4:		lodsb
		stosb
		cmp al, 0
		jne .4
		pop eax
		xchg esi, edx
		pop edi
		ret

global SYM($strcmp)
SYM($strcmp):
		push esi
		xchg eax, esi
		xor eax, eax
		xchg edi, edx
.5:		lodsb
		scasb
		jne .6
		cmp al, 0
		jne .5
		jmp .7
.6:		mov al, 1
		jae .7
		neg eax
.7:		xchg edi, edx
		pop esi
		ret

global SYM($memcpy)
SYM($memcpy):
		push edi
		xchg esi, edx
		xchg edi, eax		; EDI := dest; EAX := junk.
%ifnidn REGARG3,ecx
		xchg ecx, REGARG3
%endif
		push edi
		rep movsb
		pop eax			; Will return dest.
%ifnidn REGARG3,ecx
		xchg ecx, REGARG3	; Restore ECX from REGARG3. And REGARG3 is scratch, we don't care what we put there.
%endif
		xchg esi, edx		; Restore ESI.
		pop edi
		ret

%endif  ; ifndef FEATURES_WE

; --- Linux i386 syscall (system call) functions.

%ifndef FEATURES_WE

global SYM($sys_brk)
SYM($sys_brk):
		push byte 45		; __NR_brk.
		jmp short __do_syscall3

global SYM($unlink)
SYM($unlink):
global SYM($remove)
SYM($remove):
		push byte 10		; __NR_unlink.
		jmp short __do_syscall3

global SYM($close)
SYM($close):
		push byte 6		; __NR_close.
		jmp short __do_syscall3


global SYM($creat)
SYM($creat):
		push byte 8		; __NR_creat.
		jmp short __do_syscall3

global SYM($rename)
SYM($rename):
		push byte 38		; __NR_rename.
		jmp short __do_syscall3

global SYM($open)
SYM($open):  ; With 2 or 3 arguments, arg3 is mode.
global SYM($open3)
SYM($open3):  ; With 2 or 3 arguments, arg3 is mode.
		push byte 5		; __NR_open.
		jmp short __do_syscall3

global SYM($read)
SYM($read):
		push byte 3		; __NR_read.
		jmp short __do_syscall3

global SYM($lseek)
SYM($lseek):
		push byte 19		; __NR_lseek.
		jmp short __do_syscall3


global SYM($chdir)
SYM($chdir):
		push byte 12		; __NR_chdir.
		jmp short __do_syscall3

global SYM($mkdir)
SYM($mkdir):
		push byte 39		; __NR_mkdir.
		jmp short __do_syscall3

global SYM($rmdir)
SYM($rmdir):
		push byte 40		; __NR_rmdir.
		jmp short __do_syscall3

global SYM($getpid)
SYM($getpid):
		push byte 20		; __NR_getpid.
		jmp short __do_syscall3

%endif  ; ifndef FEATURES_WE

global SYM($write)
SYM($write):
		push byte 4		; __NR_write.
		jmp short __do_syscall3

; --- Entry and exit().

global $_start
%ifidn __OUTPUT_FORMAT__,obj
extern SYM($main_from_libc)
..start:
%endif
%ifidn __OUTPUT_FORMAT__,elf
extern $main  ; No SYM(...), this is user-defined.
%endif
%ifidn __OUTPUT_FORMAT__,bin
SYM($main_from_libc) equ $$  ; Dummy value to avoid undefined symbols.
%endif
$_start:  ; Program entry point.
		pop eax			; argc.
		mov edx, esp		; argv.
%ifidn REGARG3,ebx  ; __watcall.
		call SYM($main_from_libc)
%else  ; regparm(3).
		push edx  ; Make it also work if main(...) is regparm(0), e.g. `gcc' without `-mregparm=3'. TODO(pts): When can we be sure GCC was using regparm(3) thus remove these pushes? Do a little test on the gcc assembly output.
		push eax
		call $main
%endif
		; Fall through to exit_.
global SYM($exit)
SYM($exit):
		push byte 1		; __NR_exit.
__do_syscall3:	; Do system call of up to 3 argumnts: dword[esp]: syscall number, eax: arg1, edx: arg2, ebx: arg3.
		xchg REGNARG, [esp]	; Keep REGNARG pushed.
		xchg eax, ebx
%ifidn REGARG3,ebx  ; __watcall.
		xchg eax, edx
		xchg eax, ecx
%else  ; regparm(3).
		xchg ecx, edx
%endif
		push edx
		push REGARG3
		int 80h
		test eax, eax
		jns .8
		or eax, byte -1
.8:		pop REGARG3
		pop edx
		pop REGNARG
		ret
		; This would also work, but it is longer:
		;xchg eax, ebx
		;xor eax, eax
		;inc eax
		;int 80h


; --- Functions using the Linux i386 syscalls.

%ifndef FEATURES_WE

; Implemented using sys_brk(2).
global SYM($malloc)
SYM($malloc):
		push ecx
		push edx
		mov edx, eax
		test eax, eax
		jg .14
.13:		xor eax, eax
		pop edx
		pop ecx
		ret
.14:		mov eax, [$__malloc_base]
		test eax, eax
		jne .15
		call SYM($sys_brk)
		mov [$__malloc_free], eax
		mov [$__malloc_base], eax
		test eax, eax
		je .18
		mov ecx, 10000h		; 64 KiB minimum allocation.
		add eax, ecx
		mov [$__malloc_end], eax
		jmp .16
.15:		mov eax, [$__malloc_end]
		sub eax, [$__malloc_free]
		cmp edx, eax
		jbe .17
		mov ecx, [$__malloc_end]
		sub ecx, [$__malloc_base]
		add ecx, ecx
		test ecx, ecx
		jnle .13
.16:		mov eax, [$__malloc_base]
		add eax, ecx
		cmp eax, [$__malloc_base]
		jb .13
		mov eax, [$__malloc_base]
		add eax, ecx
		mov [$__malloc_end], eax
		call SYM($sys_brk)
		cmp eax, [$__malloc_end]
		je .15
		jmp .13
.17:		add [$__malloc_free], edx
		mov eax, [$__malloc_free]
		sub eax, edx
.18:		pop edx
		pop ecx
		ret

%endif  ; ifndef FEATURES_WE

; --- 64-bit integer multiplication, division, modulo and shifts.

%ifdef FEATURES_INT64

%ifidn __OUTPUT_FORMAT__,elf  ; GCC.

; GCC regparm(0): gcc -mregparm=0 -Wl,wrap=__umoddi3  -- still inconvenient for the user to remember.
; !! Everywhere. Remove duplicate code?
global __wrap___divdi3
__wrap___divdi3:
		push ebp
		mov ebp, esp
		push edi
		push esi
		mov eax, [ebp+0x8]
		mov edx, [ebp+0xc]
		mov esi, [ebp+0x10]
		mov edi, [ebp+0x14]
		jmp short __divdi3__RP3__.start

; For GCC.
global __divdi3  ; No SYM(...), GCC compiler calls it like this.
__divdi3:
global __divdi3__RP3__
__divdi3__RP3__:
		push ebp
		mov ebp, esp
		push edi
		push esi
		;
		; These commented out movs are for regparm(0).
		;mov eax, [ebp+0x8]
		;mov edx, [ebp+0xc]
		;mov esi, [ebp+0x10]
		;mov edi, [ebp+0x14]
		mov esi, [ebp+0x8]
		mov edi, [ebp+0xc]
		;
.start:		sub esp, 0x30
		mov [ebp-0x24], edx
		mov ecx, [ebp-0x24]
		mov [ebp-0x28], eax
		mov eax, esi
		mov dword [ebp-0x30], 0x0
		mov edx, edi
		mov dword [ebp-0x2c], 0x0
		test ecx, ecx
		mov dword [ebp-0x1c], 0x0
		js .1143
.13e:		test edi, edi
		js .1130
.146:		mov edi, edx
		mov esi, eax
		mov edx, [ebp-0x28]
		mov ecx, eax
		mov eax, [ebp-0x24]
		test edi, edi
		mov [ebp-0x10], edx
		mov [ebp-0x14], eax
		jne .180
		cmp esi, eax
		ja .1b1
		test esi, esi
		je .1180
.168:		mov eax, [ebp-0x14]
		mov edx, edi
		div ecx
		mov esi, eax
		mov eax, [ebp-0x10]
		div ecx
		mov ecx, eax
		mov eax, esi
		jmp .190
.180:		cmp edi, [ebp-0x14]
		jbe .1c0
.185:		xor ecx, ecx
		xor eax, eax
.190:		mov [ebp-0x30], ecx
		mov ecx, [ebp-0x1c]
		mov [ebp-0x2c], eax
		mov eax, [ebp-0x30]
		mov edx, [ebp-0x2c]
		test ecx, ecx
		je .1aa
		neg eax
		adc edx, 0x0
		neg edx
.1aa:		add esp, 0x30
		pop esi
		pop edi
		pop ebp
		ret
.1b1:		mov eax, edx
		mov edx, [ebp-0x14]
		div esi
		mov ecx, eax
		xor eax, eax
		jmp .190
		mov esi, esi
.1c0:		bsr eax, edi
		xor eax, 0x1f
		mov [ebp-0x18], eax
		je .1160
		mov edx, [ebp-0x18]
		mov eax, 0x20
		movzx ecx, byte [ebp-0x18]
		sub eax, edx
		mov edx, edi
		mov [ebp-0xc], eax
		shl edx, cl
		mov eax, esi
		movzx ecx, byte [ebp-0xc]
		mov edi, edx
		mov edx, [ebp-0x10]
		shr eax, cl
		movzx ecx, byte [ebp-0x18]
		or edi, eax
		mov eax, [ebp-0x14]
		shl esi, cl
		shl eax, cl
		movzx ecx, byte [ebp-0xc]
		shr edx, cl
		or eax, edx
		mov edx, [ebp-0x14]
		mov [ebp-0x34], eax
		shr edx, cl
		div edi
.1110:		mov [ebp-0x34], edx
		mov [ebp-0x38], eax
		mul esi
		cmp [ebp-0x34], edx
		mov edi, eax
		jb .119d
		je .1190
.1121:		mov ecx, [ebp-0x38]
		xor eax, eax
		jmp .190
.1130:		mov eax, esi
		mov edx, edi
		neg eax
		adc edx, 0x0
.1139:		neg edx
		not dword [ebp-0x1c]
		jmp .146
.1143:		neg dword [ebp-0x28]
		mov dword [ebp-0x1c], 0xffffffff
		adc dword [ebp-0x24], 0x0
		neg dword [ebp-0x24]
		jmp .13e
.1160:		cmp edi, [ebp-0x14]
		jb .116e
		cmp esi, [ebp-0x10]
		ja .185
.116e:		mov ecx, 0x1
		xor eax, eax
		jmp .190
.1180:		mov eax, 0x1
		xor edx, edx
		div esi
		mov ecx, eax
		jmp .168
.1190:		mov eax, [ebp-0x10]
		movzx ecx, byte [ebp-0x18]
		shl eax, cl
		cmp eax, edi
		jae .1121
.119d:		mov ecx, [ebp-0x38]
		xor eax, eax
		dec ecx
		jmp .190

; GCC regparm(0): gcc -mregparm=0 -Wl,wrap=__umoddi3  -- still inconvenient for the user to remember.
; !! Everywhere. Remove duplicate code?
global __wrap___udivdi3
__wrap___udivdi3:
		push ebp
		mov ebp, esp
		push edi
		mov eax, [ebp+0x8]
		mov edx, [ebp+0xc]
		mov ecx, [ebp+0x10]
		mov edi, [ebp+0x14]
		jmp short __udivdi3__RP3__.start

global __udivdi3:
__udivdi3:
global __udivdi3__RP3__
__udivdi3__RP3__:
		push ebp
		mov ebp, esp
		push edi
		;
		; These commented out movs are for regparm(0).
		;mov eax, [ebp+0x8]
		;mov edx, [ebp+0xc]
		;mov ecx, [ebp+0x10]
		;mov edi, [ebp+0x14]
		mov ecx, [ebp+0x8]
		mov edi, [ebp+0xc]
		;
.start:		push esi
		sub esp, 0x28
		mov [ebp-0xc], ecx
		mov [ebp-0x14], eax
		mov [ebp-0x18], edx
		mov dword [ebp-0x28], 0x0
		mov dword [ebp-0x24], 0x0
		test edi, edi
		jne .263
		cmp ecx, edx
		jbe .2d5
		div ecx
		mov ecx, eax
		xor eax, eax
.250:		mov [ebp-0x24], eax
		mov [ebp-0x28], ecx
		mov edx, [ebp-0x24]
		mov eax, [ebp-0x28]
		add esp, 0x28
		pop esi
		pop edi
		pop ebp
		ret
.263:		cmp edi, [ebp-0x18]
		ja .2100
		bsr eax, edi
		xor eax, 0x1f
		mov [ebp-0x1c], eax
		je .2f3
		mov edx, [ebp-0x1c]
		mov eax, 0x20
		movzx ecx, byte [ebp-0x1c]
		mov esi, [ebp-0xc]
		sub eax, edx
		mov edx, edi
		mov [ebp-0x10], eax
		shl edx, cl
		mov eax, [ebp-0xc]
		movzx ecx, byte [ebp-0x10]
		mov edi, edx
		mov edx, [ebp-0x14]
		shr eax, cl
		movzx ecx, byte [ebp-0x1c]
		or edi, eax
		mov eax, [ebp-0x18]
		shl esi, cl
		shl eax, cl
.2aa:		movzx ecx, byte [ebp-0x10]
		shr edx, cl
		or eax, edx
		mov edx, [ebp-0x18]
		mov [ebp-0x2c], eax
		shr edx, cl
		div edi
		mov edi, edx
		mov [ebp-0x30], eax
		mul esi
		cmp edi, edx
		mov esi, eax
		jb .2139
		je .212c
.2cb:		mov ecx, [ebp-0x30]
		xor eax, eax
		jmp .250
.2d5:		mov esi, [ebp-0xc]
		test esi, esi
		je .2110
.2dc:		mov eax, [ebp-0x18]
		mov edx, edi
		div ecx
		mov esi, eax
		mov eax, [ebp-0x14]
		div ecx
		mov ecx, eax
		mov eax, esi
		jmp .250
.2f3:		cmp edi, [ebp-0x18]
		jb .2120
		mov edx, [ebp-0x14]
		cmp [ebp-0xc], edx
		jbe .2120
.2100:		xor ecx, ecx
		xor eax, eax
		jmp .250
.2110:		mov eax, 0x1
		xor edx, edx
		div dword [ebp-0xc]
		mov ecx, eax
		jmp .2dc
		mov esi, esi
.2120:		mov ecx, 0x1
		xor eax, eax
		jmp .250
.212c:		mov eax, [ebp-0x14]
		movzx ecx, byte [ebp-0x1c]
		shl eax, cl
		cmp eax, esi
		jae .2cb
.2139:		mov ecx, [ebp-0x30]
		xor eax, eax
		dec ecx
		jmp .250

; GCC regparm(0): gcc -mregparm=0 -Wl,wrap=__umoddi3  -- still inconvenient for the user to remember.
; !! Everywhere. Remove duplicate code?
global __wrap___moddi3
__wrap___moddi3:
		push ebp
		mov ebp, esp
		push edi
		push esi
		mov esi, [ebp+0x8]
		mov edi, [ebp+0xc]
		mov eax, [ebp+0x10]
		mov edx, [ebp+0x14]
		jmp short __moddi3__RP3__.start

; For GCC.
global __moddi3  ; No SYM(...), GCC compiler calls it like this.
__moddi3:
global __moddi3__RP3__
__moddi3__RP3__:
		push ebp
		mov ebp, esp
		push edi
		push esi
		; These commented out movs are for regparm(0).
		;mov esi, [ebp+0x8]
		;mov edi, [ebp+0xc]
		;mov eax, [ebp+0x10]
		;mov edx, [ebp+0x14]
		xchg esi, eax  ; ESI := EAX. EAX := junk.
		mov edi, edx
		mov eax, [ebp+0x8]
		mov edx, [ebp+0xc]
		;
.start:		sub esp, 0x50
		mov dword [ebp-0x48], 0x0
		test edi, edi
		mov dword [ebp-0x44], 0x0
		mov [ebp-0x50], eax
		mov [ebp-0x4c], edx
		mov dword [ebp-0x3c], 0x0
		js .31a2
.337:		mov ecx, [ebp-0x4c]
		test ecx, ecx
		js .3190
.342:		lea ecx, [ebp-0x10]
		test edx, edx
		mov [ebp-0x24], ecx
		mov ecx, eax
		mov [ebp-0x28], eax
		mov [ebp-0x2c], edx
		mov [ebp-0x20], esi
		mov [ebp-0x34], edi
		jne .382
		cmp eax, edi
		mov edx, edi
		jbe .3170
		mov eax, esi
		div ecx
.368:		mov [ebp-0x48], edx
		mov dword [ebp-0x44], 0x0
.372:		mov ecx, [ebp-0x24]
		mov eax, [ebp-0x48]
		mov edx, [ebp-0x44]
		mov [ecx], eax
		mov [ecx+0x4], edx
		jmp .3a0
.382:		mov eax, [ebp-0x34]
		cmp [ebp-0x2c], eax
		jbe .3c0
		mov [ebp-0x48], esi
		mov [ebp-0x44], edi
		mov edx, [ebp-0x48]
		mov ecx, [ebp-0x44]
		mov [ebp-0x10], edx
		mov [ebp-0xc], ecx
.3a0:		mov eax, [ebp-0x3c]
		test eax, eax
		je .3b1
		neg dword [ebp-0x10]
		adc dword [ebp-0xc], 0x0
		neg dword [ebp-0xc]
.3b1:		mov eax, [ebp-0x10]
		mov edx, [ebp-0xc]
		add esp, 0x50
		pop esi
		pop edi
		pop ebp
		ret
		mov esi, esi
.3c0:		bsr eax, [ebp-0x2c]
		xor eax, 0x1f
		mov [ebp-0x38], eax
		je .31c3
		mov edx, [ebp-0x38]
		mov eax, 0x20
		movzx ecx, byte [ebp-0x38]
		mov esi, [ebp-0x28]
		mov edi, [ebp-0x20]
		sub eax, edx
		mov edx, [ebp-0x2c]
		mov [ebp-0x30], eax
		mov eax, [ebp-0x28]
		shl edx, cl
		movzx ecx, byte [ebp-0x30]
		shr eax, cl
		movzx ecx, byte [ebp-0x38]
		or edx, eax
		mov eax, [ebp-0x34]
		mov [ebp-0x1c], edx
		mov edx, [ebp-0x20]
		shl esi, cl
		shl eax, cl
		movzx ecx, byte [ebp-0x30]
		shr edx, cl
		movzx ecx, byte [ebp-0x38]
		or eax, edx
		mov edx, [ebp-0x34]
		shl edi, cl
		movzx ecx, byte [ebp-0x30]
		shr edx, cl
		div dword [ebp-0x1c]
		mov [ebp-0x54], edx
		mul esi
		cmp [ebp-0x54], edx
		jb .320d
		je .3205
.3136:		mov ecx, [ebp-0x54]
		sub edi, eax
		sbb ecx, edx
		mov [ebp-0x54], ecx
		mov edx, ecx
		movzx ecx, byte [ebp-0x30]
		mov eax, edi
		shl edx, cl
		movzx ecx, byte [ebp-0x38]
		shr eax, cl
		or edx, eax
		mov eax, [ebp-0x54]
		mov [ebp-0x48], edx
		mov edx, [ebp-0x48]
		shr eax, cl
		mov [ebp-0x44], eax
		mov eax, [ebp-0x24]
		mov ecx, [ebp-0x44]
		mov [eax], edx
		mov [eax+0x4], ecx
		jmp .3a0
.3170:		mov esi, [ebp-0x28]
		test esi, esi
		je .31b5
.3177:		mov eax, [ebp-0x34]
		mov edx, [ebp-0x2c]
		div ecx
		mov eax, [ebp-0x20]
		div ecx
		jmp .368
.3190:		mov eax, [ebp-0x50]
		mov edx, [ebp-0x4c]
		neg eax
		adc edx, 0x0
		neg edx
		jmp .342
.31a2:		neg esi
		adc edi, 0x0
		neg edi
		mov dword [ebp-0x3c], 0xffffffff
		jmp .337
.31b5:		mov eax, 0x1
		xor edx, edx
		div dword [ebp-0x28]
		mov ecx, eax
		jmp .3177
.31c3:		mov ecx, [ebp-0x34]
		cmp [ebp-0x2c], ecx
		jb .31f1
		mov eax, [ebp-0x20]
		cmp [ebp-0x28], eax
		jbe .31f1
.31e0:		mov eax, [ebp-0x20]
		mov edx, [ebp-0x34]
		mov [ebp-0x48], eax
		mov [ebp-0x44], edx
		jmp .372
.31f1:		mov edx, [ebp-0x34]
		mov ecx, [ebp-0x20]
		sub ecx, [ebp-0x28]
		sbb edx, [ebp-0x2c]
		mov [ebp-0x20], ecx
		mov [ebp-0x34], edx
		jmp .31e0
.3205:		cmp edi, eax
		jae .3136
.320d:		sub eax, esi
		sbb edx, [ebp-0x1c]
		jmp .3136


; GCC regparm(0): gcc -mregparm=0 -Wl,wrap=__umoddi3  -- still inconvenient for the user to remember.
; !! Everywhere.
global __wrap___umoddi3
__wrap___umoddi3:
		push ebp
		mov ebp, esp
		push edi
		push esi
		mov esi, [ebp+0x8]
		mov edi, [ebp+0xc]
		mov eax, [ebp+0x10]
		mov edx, [ebp+0x14]
		jmp short __umoddi3__RP3__.start

; For GCC.
global __umoddi3  ; No SYM(...), GCC compiler calls it like this, but it's still regparm(3). !! How do we make it also work with -mregparm=0?? We can't. !!!
__umoddi3:
global __umoddi3__RP3__
__umoddi3__RP3__:
		push ebp
		mov ebp, esp
		push edi
		push esi
		;
		; These commented out movs are for regparm(0).
		;mov esi, [ebp+0x8]
		;mov edi, [ebp+0xc]
		;mov eax, [ebp+0x10]
		;mov edx, [ebp+0x14]
		xchg esi, eax  ; ESI := EAX. EAX := junk.
		mov edi, edx
		mov eax, [ebp+0x8]
		mov edx, [ebp+0xc]
		;
.start:		sub esp, 0x30
		test edx, edx
		mov dword [ebp-0x30], 0x0
		mov ecx, eax
		mov dword [ebp-0x2c], 0x0
		mov [ebp-0x14], eax
		mov [ebp-0x18], edx
		mov [ebp-0x10], esi
		mov [ebp-0x20], edi
		jne .460
		cmp eax, edi
		mov edx, edi
		jbe .4130
		mov eax, esi
		div ecx
.442:		mov [ebp-0x30], edx
		mov dword [ebp-0x2c], 0x0
		mov eax, [ebp-0x30]
		mov edx, [ebp-0x2c]
.ret:		add esp, 0x30
		pop esi
		pop edi
		pop ebp
		ret
.460:		mov ecx, [ebp-0x20]
		cmp [ebp-0x18], ecx
		jbe .480
		mov [ebp-0x30], esi
		mov [ebp-0x2c], edi
		mov eax, [ebp-0x30]
		mov edx, [ebp-0x2c]
		jmp short .ret
.480:		bsr eax, [ebp-0x18]
		xor eax, 0x1f
		mov [ebp-0x24], eax
		je .4160
		mov edx, [ebp-0x24]
		mov eax, 0x20
		movzx ecx, byte [ebp-0x24]
		mov esi, [ebp-0x14]
		mov edi, [ebp-0x10]
		sub eax, edx
		mov edx, [ebp-0x18]
		mov [ebp-0x1c], eax
		mov eax, [ebp-0x14]
		shl edx, cl
		movzx ecx, byte [ebp-0x1c]
		shr eax, cl
		movzx ecx, byte [ebp-0x24]
		or edx, eax
		mov eax, [ebp-0x20]
		mov [ebp-0xc], edx
		mov edx, [ebp-0x10]
		shl esi, cl
		shl eax, cl
		movzx ecx, byte [ebp-0x1c]
		shr edx, cl
		movzx ecx, byte [ebp-0x24]
		or eax, edx
		mov edx, [ebp-0x20]
		shl edi, cl
		movzx ecx, byte [ebp-0x1c]
		shr edx, cl
		div dword [ebp-0xc]
		mov [ebp-0x34], edx
		mul esi
		cmp [ebp-0x34], edx
		jb .41a5
		je .419d
.4f6:		mov ecx, [ebp-0x34]
		sub edi, eax
		sbb ecx, edx
		mov [ebp-0x34], ecx
		mov edx, ecx
		movzx ecx, byte [ebp-0x1c]
		mov eax, edi
		shl edx, cl
		movzx ecx, byte [ebp-0x24]
		shr eax, cl
		or edx, eax
		mov eax, [ebp-0x34]
		mov [ebp-0x30], edx
		shr eax, cl
		mov [ebp-0x2c], eax
		mov eax, [ebp-0x30]
		mov edx, [ebp-0x2c]
.ret2:		jmp .ret
.4130:		mov esi, [ebp-0x14]
		test esi, esi
		je .4150
.4137:		mov eax, [ebp-0x20]
		mov edx, [ebp-0x18]
		div ecx
		mov eax, [ebp-0x10]
		div ecx
		jmp .442
.4150:		mov eax, 0x1
		xor edx, edx
		div dword [ebp-0x14]
		mov ecx, eax
		jmp .4137
		mov esi, esi
.4160:		mov eax, [ebp-0x20]
		cmp [ebp-0x18], eax
		jb .4189
		mov edx, [ebp-0x10]
		cmp [ebp-0x14], edx
		jbe .4189
.4170:		mov edx, [ebp-0x10]
		mov ecx, [ebp-0x20]
		mov [ebp-0x30], edx
		mov [ebp-0x2c], ecx
		mov eax, [ebp-0x30]
		mov edx, [ebp-0x2c]
		jmp short .ret2
.4189:		mov ecx, [ebp-0x20]
		mov eax, [ebp-0x10]
		sub eax, [ebp-0x14]
		sbb ecx, [ebp-0x18]
		mov [ebp-0x10], eax
		mov [ebp-0x20], ecx
		jmp .4170
.419d:		cmp edi, eax
		jae .4f6
.41a5:		sub eax, esi
		sbb edx, [ebp-0xc]
		jmp .4f6

%else  ; OpenWatcom.

; For OpenWatcom. Uses __U8D.
global $__I8D  ; No SYM(...), the OpenWatcom C compiler calls it like this.
$__I8D:
		or edx, edx
		js .2
		or ecx, ecx
		js .1
		call $__U8D
		ret
.1:		neg ecx
		neg ebx
		sbb ecx, 0
		call $__U8D
		neg edx
		neg eax
		sbb edx, 0
		ret
.2:		neg edx
		neg eax
		sbb edx, 0
		or ecx, ecx
		jns .3
		neg ecx
		neg ebx
		sbb ecx, 0
		call $__U8D
		neg ecx
		neg ebx
		sbb ecx, 0
		ret
.3:		call $__U8D
		neg ecx
		neg ebx
		sbb ecx, 0
		neg edx
		neg eax
		sbb edx, 0
		ret

; For OpenWatcom.
global $__U8D  ; No SYM(...), the OpenWatcom C compiler calls it like this.
$__U8D:
		or ecx, ecx
		jne .6
		dec ebx
		je .5
		inc ebx
		cmp ebx, edx
		ja .4
		mov ecx, eax
		mov eax, edx
		sub edx, edx
		div ebx
		xchg eax, ecx
.4:		div ebx
		mov ebx, edx
		mov edx, ecx
		sub ecx, ecx
.5:		ret
.6:		cmp ecx, edx
		jb .8
		jne .7
		cmp ebx, eax
		ja .7
		sub eax, ebx
		mov ebx, eax
		sub ecx, ecx
		sub edx, edx
		mov eax, 1
		ret
.7:		sub ecx, ecx
		sub ebx, ebx
		xchg eax, ebx
		xchg edx, ecx
		ret
.8:		push ebp
		push esi
		push edi
		sub esi, esi
		mov edi, esi
		mov ebp, esi
.9:		add ebx, ebx
		adc ecx, ecx
		jb .12
		inc ebp
		cmp ecx, edx
		jb .9
		ja .10
		cmp ebx, eax
		jbe .9
.10:		clc
.11:		adc esi, esi
		adc edi, edi
		dec ebp
		js .15
.12:		rcr ecx, 1
		rcr ebx, 1
		sub eax, ebx
		sbb edx, ecx
		cmc
		jb .11
.13:		add esi, esi
		adc edi, edi
		dec ebp
		js .14
		shr ecx, 1
		rcr ebx, 1
		add eax, ebx
		adc edx, ecx
		jae .13
		jmp .11
.14:		add eax, ebx
		adc edx, ecx
.15:		mov ebx, eax
		mov ecx, edx
		mov eax, esi
		mov edx, edi
		pop edi
		pop esi
		pop ebp
		ret

; For OpenWatcom.
global $__U8M  ; No SYM(...), the OpenWatcom C compiler calls it like this.
$__U8M:
global $__I8M  ; No SYM(...), the OpenWatcom C compiler calls it like this.
$__I8M:
		test edx, edx
		jne .1
		test ecx, ecx
		jne .1
		mul ebx
		ret
.1:		push eax
		push edx
		mul ecx
		mov ecx, eax
		pop eax
		mul ebx
		add ecx, eax
		pop eax
		mul ebx
		add edx, ecx
		ret

; For OpenWatcom.
global $__U8RS  ; No SYM(...), the OpenWatcom C compiler calls it like this.

$__U8RS:
		mov ecx, ebx
		and cl, 3fh
		test cl, 20h
		jne .1
		shrd eax, edx, cl
		shr edx, cl
		ret
.1:		mov eax, edx
		sub ecx, 20h
		xor edx, edx
		shr eax, cl
		ret

; For OpenWatcom.
global $__I8RS  ; No SYM(...), the OpenWatcom C compiler calls it like this.
$__I8RS:
		mov ecx, ebx
		and cl, 3fh
		test cl, 20h
		jne .2
		shrd eax, edx, cl
		sar edx, cl
		ret
.2:		mov eax, edx
		sub cl, 20h
		sar edx, 1fh
		sar eax, cl
		ret

; For OpenWatcom.
global $__U8LS  ; No SYM(...), the OpenWatcom C compiler calls it like this.
$__U8LS:
global $__I8LS  ; No SYM(...), the OpenWatcom C compiler calls it like this.
$__I8LS:
		mov ecx, ebx
		and cl, 3fh
		test cl, 20h
		jne .3
		shld edx, eax, cl
		shl eax, cl
		ret
.3:		mov edx, eax
		sub cl, 20h
		xor eax, eax
		shl edx, cl
		ret

%endif  ; GCC or OpenWatcom.

%endif

; --- Rest of the program code, to avoid undefined labels.

		section _BSS

$__malloc_base	resd 1  ; char *base;
$__malloc_free	resd 1  ; char *free;
$__malloc_end	resd 1  ; char, *end;

; __END__
