;
; minilibc32.nasm: size-optimized minimalistic libc for Linux i386
; by pts@fazekas.hu at Sun Nov 27 03:25:15 CET 2022
;
; Compile for OpenWatcom: nasm-0.98.39 -O9 -f obj -o minilibc32.obj minilibc32.nasm
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
; TODO(pts): Convert this NASM source to WASM and GNU as, and drop NASM as a dependency.
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
		section .bss align=1
		section .text
%define _BSS .bss  ; Section name.
%endif

; --- Generic i386 functions.

%ifndef FEATURES_WE  ; FEATURES_WE means write(...) + exit(...) only, for hello-world benchmark.

global $isalpha_
$isalpha_:
		or al, 20h
		sub al, 61h
		cmp al, 1ah
		sbb eax, eax
		neg eax
		ret

global $isspace_
$isspace_:
		sub al, 9
		cmp al, 5
		jb .1
		sub al, 17h
		cmp al, 1
.1:		sbb eax, eax
		neg eax
		ret

global $isdigit_
$isdigit_:
		sub al, 30h
		cmp al, 0ah
		sbb eax, eax
		neg eax
		ret

global $isxdigit_
$isxdigit_:
		sub al, 30h
		cmp al, 0ah
		jb .2
		or al, 20h
		sub al, 31h
		cmp al, 6
.2:		sbb eax, eax
		neg eax
		ret

global $strlen_
$strlen_:
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

global $strcpy_
$strcpy_:
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

global $strcmp_
$strcmp_:
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

%endif  ; ifndef FEATURES_WE

; --- Linux i386 syscall (system call) functions.

%ifndef FEATURES_WE

global $sys_brk_
$sys_brk_:
		push byte 45		; __NR_brk.
		jmp short __do_syscall3

global $unlink_
$unlink_:
global $remove_
$remove_:
		push byte 10		; __NR_unlink.
		jmp short __do_syscall3

global $close_
$close_:
		push byte 6		; __NR_close.
		jmp short __do_syscall3


global $creat_
$creat_:
		push byte 8		; __NR_creat.
		jmp short __do_syscall3

global $rename_
$rename_:
		push byte 38		; __NR_rename.
		jmp short __do_syscall3  ; !! TODO(pts): merge all to __do_syscall3.

global $open3_
$open3_:
		push byte 5		; __NR_open.
		jmp short __do_syscall3

global $read_
$read_:
		push byte 3		; __NR_read.
		jmp short __do_syscall3

global $lseek_
$lseek_:
		push byte 19		; __NR_lseek.
		jmp short __do_syscall3

%endif  ; ifndef FEATURES_WE

global $write_
$write_:
		push byte 4		; __NR_write.
		jmp short __do_syscall3

; --- Entry and exit().

global $_start
%ifidn __OUTPUT_FORMAT__,obj
extern $main_from_libc_
..start:
%endif
%ifidn __OUTPUT_FORMAT__,bin
$main_from_libc_ equ $$  ; Dummy value to avoid undefined symbols.
%endif
$_start:  ; Program entry point.
		pop eax			; argc.
		mov edx, esp		; argv.
		call $main_from_libc_
		; Fall through to exit_.
global $exit_
$exit_:
		push byte 1		; __NR_exit.
__do_syscall3:	; Do system call of up to 3 argumnts: dword[esp]: syscall number, eax: arg1, edx: arg2, ebx: arg3.
		xchg ecx, [esp]		; Keep ecx pushed.
		xchg eax, ebx
		xchg eax, edx
		xchg eax, ecx
		push edx
		push ebx
		int 80h
		test eax, eax
		jns .8
		or eax, byte -1
.8:		pop ebx
		pop edx
		pop ecx
		ret
		; This would also work, but it is longer:
		;xchg eax, ebx
		;xor eax, eax
		;inc eax
		;int 80h


; --- Functions using the Linux i386 syscalls.

%ifndef FEATURES_WE

; Implemented using sys_brk(2).
global $malloc_
$malloc_:
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
		call $sys_brk_
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
		call $sys_brk_
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

; --- Rest of the program code, to avoid undefined labels.

		section _BSS

$__malloc_base	resd 1  ; char *base;
$__malloc_free	resd 1  ; char *free;
$__malloc_end	resd 1  ; char, *end;

; __END__
