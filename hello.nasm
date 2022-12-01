;
; hello.nasm: Linux i386 hello-world in simple NASM syntax
; by pts@fazekas.hu at Thu Dec  1 01:54:59 CET 2022
;

bits 32
cpu 386

_start:		mov eax, 4			; __NR_write on Linux.
		mov ebx, 1			; STDOUT_FILENO.
		mov ecx, message		; Message to write.
		mov edx, message.end-message	; Message size.
		int 0x80			; System call.
		xor eax, eax
		inc eax				; __NR_exit == 1.
		xor ebx, ebx			; EXIT_SUCCESS == 0.
		int 0x80			; System call.

section .rodata
message:	db 'Hello, World!', 10
.end:
