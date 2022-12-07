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
; The watcall (__watcall) calling convention of OpenWatcom passes function
; arguments in EAX, EDX, EBX, ECX, and expects the return value in EAX. The
; callee may use EAX, the arithmetic flags in EFLAGS (but not DF, which is
; expected to be 0 and must restored to 0) and all actual argument registers
; as scratch registers, and it must restore everything else.
;
; The rp3 (__attribute__((regparm(3)))) calling convention of GCC passes up
; to 3 function arguments in EAX, EDX, ECX (please note that ECX is
; different from __watcall), and pushes the rest to the stack ([esp+4],
; [esp+8] etc.; [esp] is the return address). The caller removes arguments
; from the stack. EAX, EDX and ECX and EFLAGS (but not DF) are scratch
; registers, the callee has to restore everything else.
;
; TODO(pts): Convert this NASM source to WASM and GNU as, and drop NASM as a
;     dependency. This is not a good idea (to drop), because NASM can link a
;     smaller executable program, see better_linker.txt how.
;

		bits 32
		cpu 386

;%ifdef __LIBC_WIN32
;%error 'This libc does not support Win32 yet.'  ; !! TODO(pts): Implement support.
;times -1 nop  ; Force error on NASM 0.98.39.
;%endif

; __LIBC_INCLUDED means that this .nasm source file is %included as part
; of the linking of a specific executable program. For each libc function
; needed, there will be a %define, e.g. `%define __LIBC_NEED_isxdigit_'
; for the isxdigit(...) function in the watcall calling convention.
%ifdef __LIBC_INCLUDED
  %define __LIBC_INCLUDED 1
  %define __LIBC_ENABLE_WE 1  ; write(...) + exit(...).
  %define __LIBC_ENABLE_SYSCALL 1  ; Linux syscalls other than write(...) + exit(...).
  %define __LIBC_ENABLE_GENERAL 1  ; Enable general (non-target-specific) functions.
  %define __LIBC_ENABLE_INT64 1
  %define __LIBC_ENABLE_ALLOCA 1
%else
  %define __LIBC_INCLUDED 0
  %define __LIBC_ENABLE_WE 2  ; write(...) + exit(...).
  %ifdef FEATURES_WE  ; FEATURES_WE means write(...) + exit(...) only, for hello-world benchmark.
    %define __LIBC_ENABLE_SYSCALL 0
    %define __LIBC_ENABLE_GENERAL 0
    %define __LIBC_ENABLE_INT64 0
    %define __LIBC_ENABLE_ALLOCA 0
  %else
    %define __LIBC_ENABLE_SYSCALL 2
    %define __LIBC_ENABLE_GENERAL 2
    %ifdef FEATURES_ALLOCA
      %define __LIBC_ENABLE_ALLOCA 2
    %else
      %define __LIBC_ENABLE_ALLOCA 0
    %endif
    %ifdef FEATURES_INT64
      %define __LIBC_ENABLE_INT64 2
    %else
      %define __LIBC_ENABLE_INT64 0
    %endif
  %endif
%endif

%ifidn __OUTPUT_FORMAT__,obj  ; OpenWatcom segments.
		section _TEXT  USE32 class=CODE align=1
		section CONST  USE32 class=DATA align=1  ; OpenWatcom generates align=4.
		section CONST2 USE32 class=DATA align=4
		section _DATA  USE32 class=DATA align=4
		section _BSS   USE32 class=BSS NOBITS align=4  ; NOBITS is ignored by NASM, but class=BSS works.
		group DGROUP CONST CONST2 _DATA _BSS
		section _TEXT
  %define __LIBC_BSS  _BSS   ; Section name.
  %define __LIBC_TEXT _TEXT  ; Section name.
%else
  %if __LIBC_INCLUDED==0
  ; __LIBC_INCLUDED means that this .nasm source file is %included as part
  ; of the linking of a specific executable program. For each libc function
  ; needed, there will be a %define, e.g. `%define __LIBC_NEED_isxdigit_'
  ; for the isxdigit(...) function in the watcall calling convention.
		section .bss align=4
		section .text align=1
		section .text
  %endif
  %define __LIBC_BSS  .bss   ; Section name.
  %define __LIBC_TEXT .text  ; Section name.
%endif

%define SYM_RP3(name) name %+ __RP3__  ; GCC regparm(3) calling convention is indicated for minilibc32 GCC.
%define SYM_WATCALL(name) name %+ _  ; OpenWatcom __watcall calling convention is indicated with a trailing `_' by OpenWatcom.

%macro __LIBC_CC_rp3 0  ; GCC regparm(3) calling convention.
  %define SYM(name) SYM_RP3(name)
  %define REGARG3 ecx
  %define REGNARG ebx  ; A register which is not used by the first 3 function arguments.
%endm

%macro __LIBC_CC_watcall 0  ; OpenWatcom __watcall calling convention.
  %define SYM(name) SYM_WATCALL(name)
  %define REGARG3 ebx
  %define REGNARG ecx
%endm

%macro __LIBC_CC_rp3_and_watcall 0
  %undef SYM
  %undef REGARG3
  %undef REGNARG
%endm

%define __LIBC_CC_EVIDENCE_rp3 1  ; Do we have strong evidence (e.g. abitest) that the regparm(3) (rather than regparm(0)) calling convention is used (especially for main(...))?
%ifndef __LIBC_ABI_cc__val
  %define __LIBC_CC_EVIDENCE_rp3 0
  %ifidn __OUTPUT_FORMAT__,elf  ; Guess GCC regparm(3) calling convention.
    %define __LIBC_ABI_cc__val rp3
    ;%define __LIBC_ABI_cc_rp3
  %else  ; Guess OpenWatcom __watcall calling convention, typically if __OUTPUT_FORMAT__ is obj or bin.
    %define __LIBC_ABI_cc__val watcall
    ;%define __LIBC_ABI_cc_watcall
  %endif
%endif

%define __LIBC_CC_IS_rp3 0
%define __LIBC_CC_IS_watcall 0
%ifidn __LIBC_ABI_cc__val,rp3
  %define __LIBC_CC __LIBC_CC_rp3
  %define __LIBC_CC_IS_rp3 1
%elifidn __LIBC_ABI_cc__val,rp0  ; Uncommon, not recommended GCC.
  %define __LIBC_CC_EVIDENCE_rp3 0
  %define __LIBC_CC __LIBC_CC_rp3
  %define __LIBC_CC_IS_rp3 1
%elifidn __LIBC_ABI_cc__val,watcall
  %define __LIBC_CC_EVIDENCE_rp3 0
  %define __LIBC_CC __LIBC_CC_watcall
  %define __LIBC_CC_IS_watcall 1
%else
  %define __LIBC_CC_EVIDENCE_rp3 0
  ; TODO(pts): Implement rp0, supported by both GCC and OpenWatcom.
  %error 'Unknown calling convention for libc.'
  %error __LIBC_ABI_cc__val
  times -1 nop  ; Force error on NASM 0.98.39.
%endif
__LIBC_CC

%macro __LIBC_FUNC 1  ; %1 is symname.
global $%1
$%1:
%endm

%macro __LIBC_CHECK_NEEDED_HELPER 2
  %ifdef __LIBC_NEED_%1
    %define __LIBC_IS_NEEDED_%2 1
  %else
    %define __LIBC_IS_NEEDED_%2 0
  %endif
%endm

%macro __LIBC_CHECK_NEEDED 1-2  ; Workaround for NASM 0.98.39, see https://stackoverflow.com/a/74683036
  __LIBC_CHECK_NEEDED_HELPER %1, asis_%2
  __LIBC_CHECK_NEEDED_HELPER %1_, watcall_%2
  __LIBC_CHECK_NEEDED_HELPER %1__RP3__, rp3_%2
%endm


%macro __LIBC_MAYBE_ADD 2
  %define __LIBC_LAST_ADDED 0
  __LIBC_CHECK_NEEDED %1
  %if (__LIBC_ENABLE_%2>1 && __LIBC_CC_IS_watcall) || __LIBC_IS_NEEDED_watcall_
    __LIBC_CC_watcall
    __LIBC_FUNC %1_
    __LIBC_FUNC_%1
    %define __LIBC_LAST_ADDED 1
  %endif
  %if (__LIBC_ENABLE_%2>1 && __LIBC_CC_IS_rp3) || __LIBC_IS_NEEDED_rp3_
    __LIBC_CC_rp3
    __LIBC_FUNC %1__RP3__
    __LIBC_FUNC_%1
    %define __LIBC_LAST_ADDED 1
  %endif
  __LIBC_CC
%endm

; TODO(pts): Undefine the macro __LIBC_FUNC_%1, or don't even define it.
%macro __LIBC_MAYBE_ADD_SAME 2
  __LIBC_CHECK_NEEDED %1
  %if __LIBC_ENABLE_%2>1 || __LIBC_IS_NEEDED_watcall_ || __LIBC_IS_NEEDED_rp3_
    __LIBC_CC_rp3_and_watcall
    %if __LIBC_IS_NEEDED_watcall_ || __LIBC_ENABLE_%2>1
      __LIBC_FUNC %1_
    %endif
    %if __LIBC_IS_NEEDED_rp3_ || __LIBC_ENABLE_%2>1
      __LIBC_FUNC %1__RP3__
    %endif
    __LIBC_FUNC_%1
  %endif
  __LIBC_CC
%endm

; Add function %1 asis (no name mangling) if %1 is needed or
; feature %2 is requested.
%macro __LIBC_MAYBE_ADD_ASIS 2
  __LIBC_CHECK_NEEDED %1
  %if __LIBC_ENABLE_%2>1 || __LIBC_IS_NEEDED_asis_
    __LIBC_CC_rp3_and_watcall
    __LIBC_FUNC %1
    __LIBC_FUNC_%1
  %endif
  __LIBC_CC
%endm

%macro __LIBC_MAYBE_ADD_ONE 1
  __LIBC_CHECK_NEEDED %1
  %if __LIBC_IS_NEEDED_watcall_ && __LIBC_CC_IS_watcall
    __LIBC_CC_watcall
    __LIBC_FUNC %1_
    __LIBC_FUNC_%1
    __LIBC_CC
  %endif
  %if __LIBC_IS_NEEDED_rp3_ && __LIBC_CC_IS_rp3
    __LIBC_CC_rp3
    __LIBC_FUNC %1__RP3__
    __LIBC_FUNC_%1
    __LIBC_CC
  %endif
%endm

%macro __LIBC_ADD_DEP_HELPER 2  ; Workaround for NASM 0.98.39, see https://stackoverflow.com/a/74683036
  %ifdef %1_
    %define %2_
  %endif
  %ifdef %1__RP3__
    %define %2__RP3__
  %endif
%endm

; Example: __LIBC_ADD_DEP malloc, sys_brk
;
; If FA depends on FB, and FB depends on FC, then add them in this order:
;
;   __LIBC_ADD_DEP FA, FB
;   __LIBC_ADD_DEP FB, FC
;
; After these, the order of __LIBC_MAYBE_ADD... doesn't matter.
%macro __LIBC_ADD_DEP 2
  __LIBC_ADD_DEP_HELPER __LIBC_NEED_%1, __LIBC_NEED_%2
%endm

%macro __LIBC_ADD_DEP_ASIS 2
  %ifdef __LIBC_NEED_%1
    %define __LIBC_NEED_%2
  %endif
%endm

; --- Generic i386 functions.

%macro __LIBC_FUNC_isalpha 0
		or al, 20h
		sub al, 61h
		cmp al, 1ah
		sbb eax, eax
		neg eax
		ret
%endm
__LIBC_MAYBE_ADD_SAME isalpha, GENERAL

%macro __LIBC_FUNC_isspace 0
		sub al, 9
		cmp al, 5
		jb .1
		sub al, 17h
		cmp al, 1
.1:		sbb eax, eax
		neg eax
		ret
%endm
__LIBC_MAYBE_ADD_SAME isspace, GENERAL

%macro __LIBC_FUNC_isdigit 0
		sub al, 30h
		cmp al, 0ah
		sbb eax, eax
		neg eax
		ret
%endm
__LIBC_MAYBE_ADD_SAME isdigit, GENERAL

%macro __LIBC_FUNC_isxdigit 0
		sub al, 30h
		cmp al, 0ah
		jb .2
		or al, 20h
		sub al, 31h
		cmp al, 6
.2:		sbb eax, eax
		neg eax
		ret
%endm
__LIBC_MAYBE_ADD_SAME isxdigit, GENERAL

%macro __LIBC_FUNC_strlen 0
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
%endm
__LIBC_MAYBE_ADD_SAME strlen, GENERAL

%macro __LIBC_FUNC_strcpy 0
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
%endm
__LIBC_MAYBE_ADD_SAME strcpy, GENERAL

%macro __LIBC_FUNC_strcmp 0
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
%endm
__LIBC_MAYBE_ADD_SAME strcmp, GENERAL

%macro __LIBC_FUNC_memcpy 0
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
%endm
__LIBC_MAYBE_ADD memcpy, GENERAL

; Needed by the TCC (__TINYC__) compiler 0.9.26.
; The ABI (register arguments) is specific to alloca, doesn't depend on -mregparm=....
; TODO(pts): Make sure that GCC uses __builtin_alloca (-fbuiltin-alloca?).
;
; FYI mark stack as nonexecutable in GNU as: .section .note.GNU-stack,"",@progbits
%macro __LIBC_FUNC_alloca 0
		pop edx
		pop eax
		add eax, 3
		and eax, ~3
		jz .1
		sub esp, eax
		mov eax, esp
.1:		push edx
		push edx
		ret
%endm
__LIBC_MAYBE_ADD_ASIS alloca, ALLOCA

; --- Functions using the Linux i386 syscalls.

%ifndef __LIBC_WIN32  ; TODO(pts): Implement support.

; Implemented using sys_brk(2).
%macro __LIBC_FUNC_malloc 0
		push ecx  ; !! TODO(pts): Not necessary to save+restore in rp3.
		push edx  ; !! TODO(pts): Not necessary to save+restore in rp3.
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
%endm
__LIBC_ADD_DEP malloc, sys_brk  ; !! TODO(pts): Automatic, based on `call'.
__LIBC_MAYBE_ADD malloc, GENERAL
%if __LIBC_LAST_ADDED
section __LIBC_BSS
$__malloc_base	resd 1  ; char *base;
$__malloc_free	resd 1  ; char *free;
$__malloc_end	resd 1  ; char *end;
section __LIBC_TEXT
%endif

%endif  ; ifndef __LIBC_WIN32

; --- Linux i386 syscall (system call) functions.

; Example: __LIBC_LINUX_SYSCALL sys_brk, 45, SYSCALL
;
; Generates 4 bytes per syscall.
%macro __LIBC_LINUX_SYSCALL 3
  %ifndef __LIBC_WIN32  ; TODO(pts): Implement support.
    __LIBC_CHECK_NEEDED %1
    %if __LIBC_CC_IS_watcall && (__LIBC_ENABLE_%3>1 || __LIBC_IS_NEEDED_watcall_)
      __LIBC_FUNC %1_
      %define __LIBC_NEED___do_syscall3_
      push byte %2
      jmp short __do_syscall3_
    %endif
    %if __LIBC_CC_IS_rp3 && (__LIBC_ENABLE_%3>1 || __LIBC_IS_NEEDED_rp3_)
      __LIBC_FUNC %1__RP3__
      %define __LIBC_NEED___do_syscall3__RP3__
      push byte %2
      jmp short __do_syscall3__RP3__
    %endif
  %endif
%endm

; Example: __LIBC_LINUX_SYSCALL_ALIAS open, open3, 5, SYSCALL
%macro __LIBC_LINUX_SYSCALL_ALIAS 4
  %ifndef __LIBC_WIN32  ; TODO(pts): Implement support.
    __LIBC_CHECK_NEEDED %1
    __LIBC_CHECK_NEEDED %2, a
    %if __LIBC_CC_IS_watcall && (__LIBC_ENABLE_%4>1 || __LIBC_IS_NEEDED_watcall_ || __LIBC_IS_NEEDED_watcall_a)
      %if __LIBC_IS_NEEDED_watcall_ || __LIBC_ENABLE_%4>1
        __LIBC_FUNC %1_
      %endif
      %if __LIBC_IS_NEEDED_watcall_a || __LIBC_ENABLE_%4>1
        __LIBC_FUNC %2_
      %endif
      %define __LIBC_NEED___do_syscall3_
      push byte %3
      jmp short __do_syscall3_
    %endif
    %if __LIBC_CC_IS_rp3 && (__LIBC_ENABLE_%4>1 || __LIBC_IS_NEEDED_rp3_ || __LIBC_IS_NEEDED_rp3_a)
      %if __LIBC_IS_NEEDED_rp3_ || __LIBC_ENABLE_%4>1
        __LIBC_FUNC %1__RP3__
      %endif
      %if __LIBC_IS_NEEDED_rp3_a || __LIBC_ENABLE_%4>1
        __LIBC_FUNC %2__RP3__
      %endif
      %define __LIBC_NEED___do_syscall3__RP3__
      push byte %3
      jmp short __do_syscall3__RP3__
    %endif
  %endif
%endm

; TODO(pts): Generate both the watcall and the rp3 variants if needed.
; (Usually it isn't needed.)

; Syscall numbers are valid for Linux i386 only.
__LIBC_LINUX_SYSCALL sys_brk, 45, SYSCALL
__LIBC_LINUX_SYSCALL_ALIAS unlink, remove, 10, SYSCALL
__LIBC_LINUX_SYSCALL close, 6, SYSCALL
__LIBC_LINUX_SYSCALL creat, 8, SYSCALL
__LIBC_LINUX_SYSCALL rename, 38, SYSCALL
__LIBC_LINUX_SYSCALL_ALIAS open, open3, 5, SYSCALL  ; With 2 or 3 arguments, arg3 is mode (e.g. 0644).
__LIBC_LINUX_SYSCALL read, 3, SYSCALL
__LIBC_LINUX_SYSCALL lseek, 19, SYSCALL
__LIBC_LINUX_SYSCALL chdir, 12, SYSCALL
__LIBC_LINUX_SYSCALL mkdir, 39, SYSCALL
__LIBC_LINUX_SYSCALL rmdir, 40, SYSCALL
__LIBC_LINUX_SYSCALL getpid, 20, SYSCALL
__LIBC_LINUX_SYSCALL write, 4, WE

; --- Entry and exit().

%ifndef __LIBC_WIN32  ; TODO(pts): Implement support.

__LIBC_ADD_DEP _start, exit
%if __LIBC_ENABLE_WE>1
%define __LIBC_NEED__start
%endif

%ifdef __LIBC_NEED__start
global $_start
%ifidn __OUTPUT_FORMAT__,obj
extern SYM($main_from_libc)
..start:
%endif
%ifidn __OUTPUT_FORMAT__,elf
extern $main  ; No SYM(...), this is user-defined.
%endif
%ifidn __OUTPUT_FORMAT__,bin
%if __LIBC_INCLUDED==0
SYM($main_from_libc) equ $$  ; Dummy value to avoid undefined symbols.
%endif
%endif
$_start:  ; Program entry point on Linux i386.
		pop eax			; argc.
		mov edx, esp		; argv.
%if __LIBC_CC_IS_watcall
		call SYM($main_from_libc)
%else  ; regparm(3).
  %if __LIBC_CC_EVIDENCE_rp3==0  ; Make it also work if main(...) is regparm(0), e.g. `gcc' without `-mregparm=3'. TODO(pts): When can we be sure GCC was using regparm(3) thus remove these pushes? Do a little test on the gcc assembly output.
		push edx
		push eax
  %endif
		call $main
%endif
		; Fall through to exit.
%endif  ; ifdef __LIBC_NEED_start

; _start falls through here.
__LIBC_CHECK_NEEDED _start
%if __LIBC_ENABLE_WE>1 || __LIBC_IS_NEEDED_asis_
  %if __LIBC_CC_IS_watcall
    %define __LIBC_NEED_exit_
  %endif
  %if __LIBC_CC_IS_rp3
    %define __LIBC_NEED_exit__RP3__
  %endif
%endif
__LIBC_CHECK_NEEDED exit
%if (__LIBC_IS_NEEDED_watcall_ && __LIBC_CC_IS_watcall) || (__LIBC_IS_NEEDED_rp3_ && __LIBC_CC_IS_rp3)
  __LIBC_FUNC SYM(exit)
		push byte 1		; __NR_exit.
%endif
		; Fall through to __do_syscall3.

; Do Linux i386 syscall (system call) of up to 3 arguments:
;
; * in dword[ESP(+4)]: syscall number, will be popped upon return
; * maybe in EAX: arg1
; * maybe in EDX: arg2
; * maybe in REGARG3 (EBX for watcall, ECX for rp3): arg3
; * out EAX: result or -1 on error
; * out EBX: kept intact for watcall, kept intact for rp3
; * out ECX: kept intact for watcall, destroyed   for rp3
; * out EDX: kept intact for watcall, destroyed   for rp3
;
; For watcall syscall0, EDX, EBX and ECX has to be kept intact.
; For watcall syscall1, EBX and ECX has to be kept intact.
; For watcall syscall2, ECX has to be kept intact.
; For rp3 syscall*, EBX has to be kept intact.
%macro __LIBC_FUNC___do_syscall3 0
		xchg REGNARG, [esp]	; Keep (ECX for watcall, EBX for rp3) pushed.
%ifidn REGARG3,ebx  ; watcall.
		push edx
		push ebx
		xchg eax, ebx
		xchg eax, edx
		xchg eax, ecx
%else  ; regparm(3).
		xchg eax, ebx
		xchg ecx, edx
%endif
		int 0x80
		test eax, eax
		jns .8
		or eax, byte -1
.8:
%ifidn REGARG3,ebx  ; watcall.
		pop ebx
		pop edx
%endif
		pop REGNARG		; Restore (ECX for watcall, EBX for rp3).
		ret
		; This would also work, but it is longer:
		;xchg eax, ebx
		;xor eax, eax
		;inc eax
		;int 80h
%endm
__LIBC_ADD_DEP exit, __do_syscall3
__LIBC_MAYBE_ADD_ONE __do_syscall3

%endif  ; ifndef __LIBC_WIN32

; --- 64-bit integer multiplication, division, modulo and shifts.

%macro __LIBC_FUNC___I8D 0
; Used by OpenWatcom directly, and used by GCC through the __udivdi3 wrapper.
; It uses __U8D.
;
; Divide (signed) EDX:EAX by ECX:EBX, store the result in EDX:EAX and the modulo in ECX:EBX.
; Keep other registers (except for EFLAGS) intact.
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
%endm
__LIBC_ADD_DEP_ASIS __moddi3, __I8D
__LIBC_ADD_DEP_ASIS __divdi3, __I8D
__LIBC_ADD_DEP_ASIS __I8D, __U8D
__LIBC_MAYBE_ADD_ASIS __I8D, INT64  ; No SYM(...), the OpenWatcom C compiler calls it like this.

; Used by OpenWatcom directly, and used by GCC through the __udivdi3 wrapper.
;
; Divide (unsigned) EDX:EAX by ECX:EBX, store the result in EDX:EAX and the modulo in ECX:EBX.
; Keep other registers (except for EFLAGS) intact.
%macro __LIBC_FUNC___U8D 0
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
%endm
__LIBC_ADD_DEP_ASIS __umoddi3, __U8D
__LIBC_ADD_DEP_ASIS __udivdi3, __U8D
__LIBC_MAYBE_ADD_ASIS __U8D, INT64  ; No SYM(...), the OpenWatcom C compiler calls it like this.

; For OpenWatcom.
%macro __LIBC_FUNC___I8M 0
		; Fall through to __U8M, same implementation.
%endm
__LIBC_ADD_DEP_ASIS __I8M, __U8M
__LIBC_MAYBE_ADD_ASIS __I8M, INT64  ; No SYM(...), the OpenWatcom C compiler calls it like this.

; For OpenWatcom.
%macro __LIBC_FUNC___U8M 0
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
%endm
__LIBC_MAYBE_ADD_ASIS __U8M, INT64  ; No SYM(...), the OpenWatcom C compiler calls it like this.

; For OpenWatcom.
%macro __LIBC_FUNC___U8RS 0
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
%endm
__LIBC_MAYBE_ADD_ASIS __U8RS, INT64  ; No SYM(...), the OpenWatcom C compiler calls it like this.

; For OpenWatcom.
%macro __LIBC_FUNC___I8RS 0
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
%endm
__LIBC_MAYBE_ADD_ASIS __I8RS, INT64  ; No SYM(...), the OpenWatcom C compiler calls it like this.

; For OpenWatcom.
%macro __LIBC_FUNC___I8LS 0
		; Fall through to __U8LS, same implementation.
%endm
__LIBC_ADD_DEP_ASIS __I8LS, __U8LS
__LIBC_MAYBE_ADD_ASIS __I8LS, INT64  ; No SYM(...), the OpenWatcom C compiler calls it like this.

; For OpenWatcom.
%macro __LIBC_FUNC___U8LS 0
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
%endm
__LIBC_MAYBE_ADD_ASIS __U8LS, INT64  ; No SYM(...), the OpenWatcom C compiler calls it like this.

%define __LIBC_GCCINT64 none
%ifndef __LIBC_ABI_cc_divdi3__val
  %ifidn __OUTPUT_FORMAT__,elf
    %if __LIBC_ENABLE_INT64>1
      %define __LIBC_GCCINT64 rp3
    %endif
  %endif
%elifidn __LIBC_ABI_cc_divdi3__val,rp0
  %define __LIBC_GCCINT64 rp0
%elifidn __LIBC_ABI_cc_divdi3__val,rp3
  %define __LIBC_GCCINT64 rp3
%endif

%ifnidn __LIBC_GCCINT64,none

; By migrating the functions below to be wrappers to the OpenWatcom
; functions $__I8D and $__U8D, this is how many bytes were saved:
;
; * Migrating __udivdi3 to $__U8D saved 126 bytes.
; * Migrating __divdi3 to $__I8D (calling $__U8D) saved an additional 291 bytes.
; * Migrating __moddi3 to the existing $__I8D saved an additional 503 bytes.
; * Migrating __umoddi3 to the existing $__U8D saved an additional 372 bytes.
;

; For GCC.
%macro __LIBC_FUNC___divdi3 0
		push ebx
%ifidn __LIBC_GCCINT64,rp0
		mov eax, [esp+0x8]
		mov edx, [esp+0xc]
		mov ebx, [esp+0x10]	; Low half of the divisor.
		mov ecx, [esp+0x14]	; High half of the divisor.
%else  ; rp3.
		mov ebx, [esp+8]	; Low half of the divisor.
		mov ecx, [esp+12]	; High half of the divisor.
%endif
		call $__I8D
		pop ebx
		ret
%endm
__LIBC_MAYBE_ADD_ASIS __divdi3, INT64  ; No SYM(...), GCC compiler calls it like this.

; For GCC.
%macro __LIBC_FUNC___udivdi3 0
		push ebx
%ifidn __LIBC_GCCINT64,rp0
		mov eax, [esp+0x8]
		mov edx, [esp+0xc]
		mov ebx, [esp+0x10]	; Low half of the divisor.
		mov ecx, [esp+0x14]	; High half of the divisor.
%else
		mov ebx, [esp+8]	; Low half of the divisor.
		mov ecx, [esp+12]	; High half of the divisor.
%endif
		call $__U8D
		pop ebx
		ret
%endm
__LIBC_MAYBE_ADD_ASIS __udivdi3, INT64  ; No SYM(...), GCC compiler calls it like this.

; For GCC.
%macro __LIBC_FUNC___moddi3 0
		push ebx
%ifidn __LIBC_GCCINT64,rp0
		mov eax, [esp+0x8]
		mov edx, [esp+0xc]
		mov ebx, [esp+0x10]	; Low half of the divisor.
		mov ecx, [esp+0x14]	; High half of the divisor.
%else
		mov ebx, [esp+8]	; Low half of the divisor.
		mov ecx, [esp+12]	; High half of the divisor.
%endif
		call $__I8D		; !! TODO(pts): Inline this call (and others) if only used once.
		xchg eax, ebx		; EAX := low half of the modulo, EBX := junk.
		mov edx, ecx
		pop ebx
		ret
%endm
__LIBC_MAYBE_ADD_ASIS __moddi3, INT64  ; No SYM(...), GCC compiler calls it like this.

; For GCC.
%macro __LIBC_FUNC___umoddi3 0
		push ebx
%ifidn __LIBC_GCCINT64,rp0
		mov eax, [esp+0x8]
		mov edx, [esp+0xc]
		mov ebx, [esp+0x10]	; Low half of the divisor.
		mov ecx, [esp+0x14]	; High half of the divisor.
%else
		mov ebx, [esp+8]	; Low half of the divisor.
		mov ecx, [esp+12]	; High half of the divisor.
%endif
		call $__U8D
		xchg eax, ebx		; EAX := low half of the modulo, EBX := junk.
		mov edx, ecx
		pop ebx
		ret
%endm
__LIBC_MAYBE_ADD_ASIS __umoddi3, INT64  ; No SYM(...), GCC compiler calls it like this.

%endif  ; ifnidn __LIBC_GCCINT64,none

; __END__
