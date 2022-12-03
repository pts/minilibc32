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
; be 0 and must restored to 0) and all actual argument registers as scratch
; registers, and it must restore everything else.
;
; The regparm(3) calling convention of GCC passes up to 3 function arguments
; in EAX, EDX, ECX (please note that ECX is different from __watcall), and
; pushes the rest to the stack ([esp+4], [esp+8] etc.; [esp] is the return
; address). The caller removes arguments from the stack. EAX, EBX and ECX
; and EFLAGS (but not DF) are scratch registers, the callee has to restore
; everything else.
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

; Used by OpenWatcom directly, and used by GCC through the __udivdi3 wrapper.
; It uses __U8D.
;
; Divide (signed) EDX:EAX by ECX:EBX, store the result in EDX:EAX and the modulo in ECX:EBX.
; Keep other registers (except for EFLAGS) intact.
global $__I8D  ; No SYM(...), the OpenWatcom C compiler calls it like this.
$__I8D:
		or edx, edx
		js .2
		or ecx, ecx
		js .1
		jmp short $__U8D
.1:		neg ecx
		neg ebx
		sbb ecx, 0
		call $__U8D
		jmp short .4
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
.4:		neg edx
		neg eax
		sbb edx, 0
		ret

; Used by OpenWatcom directly, and used by GCC through the __udivdi3 wrapper.
;
; Divide (unsigned) EDX:EAX by ECX:EBX, store the result in EDX:EAX and the modulo in ECX:EBX.
; Keep other registers (except for EFLAGS) intact.
global $__U8D  ; No SYM(...), the OpenWatcom C compiler calls it like this.
$__U8D:
		or ecx, ecx
		jnz .6			; Is ECX nonzero (divisor is >32 bits)? If yes, then do it the slow and complicated way.
		dec ebx
		jz .5			; Is the divisor 1? Then just return the dividend as the result in EDX:EAX, and return 0 as the module on ECX:EBX.
		inc ebx
		cmp ebx, edx
		ja .4			; Is the high half of the dividend (EDX) smaller than the divisor (EBX)? If yes, then the high half of the result (EDX) will be zero, and just do a 64bit/32bit == 32bit division (single `div' instruction at .4).
		mov ecx, eax
		mov eax, edx
		sub edx, edx
		div ebx
		xchg eax, ecx
.4:		div ebx			; Store the result in EAX and the modulo in EDX.
		mov ebx, edx		; Save the low half of the modulo to its final location (EBX).
		mov edx, ecx		; Set the high half of the result (either to 0 or based on the `div' above).
		sub ecx, ecx		; Set the high half of the modulo to 0 (because the divisor is 32-bit).
.5:		ret			; Early return in the divisor is fits to 32 bits.
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

%ifidn __OUTPUT_FORMAT__,elf  ; GCC.

; By migrating the functions below to be wrappers to the OpenWatcom
; functions $__I8D and $__U8D, this is how many bytes were saved:
;
; * Migrating __udivdi3 to $__U8D saved 126 bytes.
; * Migrating __divdi3 to $__I8D (calling $__U8D) saved an additional 291 bytes.
; * Migrating __moddi3 to the existing $__I8D saved an additional 503 bytes.
; * Migrating __umoddi3 to the existing $__U8D saved an additional 372 bytes.
;
; GCC regparm(0): gcc -mregparm=0 -Wl,wrap=__umoddi3  -- still inconvenient for the user to remember.
; !! Everywhere. Remove duplicate code?
global __wrap___divdi3
__wrap___divdi3:
		push ebx
		mov eax, [esp+0x8]
		mov edx, [esp+0xc]
		mov ebx, [esp+0x10]	; Low half of the divisor.
		mov ecx, [esp+0x14]	; High half of the divisor.
		jmp short __divdi3__RP3__.call

; For GCC.
global __divdi3  ; No SYM(...), GCC compiler calls it like this.
__divdi3:
global __divdi3__RP3__
__divdi3__RP3__:
		push ebx
		mov ebx, [esp+8]	; Low half of the divisor.
		mov ecx, [esp+12]	; High half of the divisor.
.call:		call $__I8D
		pop ebx
		ret


; GCC regparm(0): gcc -mregparm=0 -Wl,wrap=__umoddi3  -- still inconvenient for the user to remember.
; !! Everywhere. Remove duplicate code?
global __wrap___udivdi3
__wrap___udivdi3:
		push ebx
		mov eax, [esp+0x8]
		mov edx, [esp+0xc]
		mov ebx, [esp+0x10]	; Low half of the divisor.
		mov ecx, [esp+0x14]	; High half of the divisor.
		jmp short __udivdi3__RP3__.call

; TODO(pts): Inline some parts of $__U8D, to gain even more bytes.
global __udivdi3:
__udivdi3:
global __udivdi3__RP3__
__udivdi3__RP3__:
		push ebx
		mov ebx, [esp+8]	; Low half of the divisor.
		mov ecx, [esp+12]	; High half of the divisor.
.call:		call $__U8D
		pop ebx
		ret

; GCC regparm(0): gcc -mregparm=0 -Wl,wrap=__umoddi3  -- still inconvenient for the user to remember.
; !! Everywhere. Remove duplicate code?
global __wrap___moddi3
__wrap___moddi3:
		push ebx
		mov eax, [esp+0x8]
		mov edx, [esp+0xc]
		mov ebx, [esp+0x10]	; Low half of the divisor.
		mov ecx, [esp+0x14]	; High half of the divisor.
		jmp short __moddi3__RP3__.call

; For GCC.
global __moddi3  ; No SYM(...), GCC compiler calls it like this.
__moddi3:
global __moddi3__RP3__
__moddi3__RP3__:
		push ebx
		mov ebx, [esp+8]	; Low half of the divisor.
		mov ecx, [esp+12]	; High half of the divisor.
.call:		call $__I8D
		xchg eax, ebx		; EAX := low half of the modulo, EBX := junk.
		mov edx, ecx
		pop ebx
		ret

; GCC regparm(0): gcc -mregparm=0 -Wl,wrap=__umoddi3  -- still inconvenient for the user to remember.
; !! Everywhere.
global __wrap___umoddi3
__wrap___umoddi3:
		push ebx
		mov eax, [esp+0x8]
		mov edx, [esp+0xc]
		mov ebx, [esp+0x10]	; Low half of the divisor.
		mov ecx, [esp+0x14]	; High half of the divisor.
		jmp short __umoddi3__RP3__.call

; For GCC.
global __umoddi3  ; No SYM(...), GCC compiler calls it like this, but it's still regparm(3). !! How do we make it also work with -mregparm=0?? We can't. !!!
__umoddi3:
global __umoddi3__RP3__
__umoddi3__RP3__:
		push ebx
		mov ebx, [esp+8]	; Low half of the divisor.
		mov ecx, [esp+12]	; High half of the divisor.
.call:		call $__U8D
		xchg eax, ebx		; EAX := low half of the modulo, EBX := junk.
		mov edx, ecx
		pop ebx
		ret

%else  ; OpenWatcom.

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
