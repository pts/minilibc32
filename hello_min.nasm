;
; hello_min.nasm: minimalistic hello-world for Linux i386
; by pts@fazekas.hu at Wed Dec  7 04:13:28 CET 2022
;
; Compile: nasm -O9 -f bin -o hello_min hello_min.nasm && chmod +x hello_min
; The created executable program is 119 bytes.
; Run on Linux i386 or amd64: ./hello_min
;
; Disassemble: ndisasm -b 32 -e 0x54 hello_min
;
; ELF32 header based on
; https://www.muppetlabs.com/~breadbox/software/tiny/teensy.html
;
; To the best knowledge of the author this is the shortest Linux i386
; executable program doing hello-world without overlapping the code and data
; with the ELF32 headers.
;

		org 0x08048000

ehdr:					; Elf32_Ehdr
		db 0x7f, 'ELF'		;   e_ident[EI_MAG...]
		db 1			;   e_ident[EI_CLASS]: 32-bit
		db 1			;   e_ident[EI_DATA]: little endian
		db 1			;   e_ident[EI_VERSION]
		db 3			;   e_ident[EI_OSABI]: Linux
		db 0			;   e_ident[EI_ABIVERSION]
		db 0, 0, 0, 0, 0, 0, 0	;   e_ident[EI_PAD]
		dw 2			;   e_type
		dw 3			;   e_machine
		dd 1			;   e_version
		dd _start		;   e_entry
		dd phdr-$$		;   e_phoff
		dd 0			;   e_shoff
		dd 0			;   e_flags
		dw .size		;   e_ehsize
		dw phdr.size		;   e_phentsize
		dw 1			;   e_phnum
		dw 0			;   e_shentsize
		dw 40			;   e_shnum
		dw 0			;   e_shstrndx
.size		equ $-ehdr

phdr:					; Elf32_Phdr
		dd 1			;   p_type
		dd 0			;   p_offset
		dd $$			;   p_vaddr
		dd $$			;   p_paddr
		dd filesize		;   p_filesz
		dd filesize		;   p_memsz
		dd 5			;   p_flags: r-x: read and execute, no write
		dd 0x1000		;   p_align
.size		equ $-phdr

_start:
%ifndef __MININASM__
		bits 32
		cpu 386
		;mov ebx, 1		; STDOUT_FILENO.
		xor ebx, ebx
		inc ebx			; EBX := 1 == STDOUT_FILENO.
		lea eax, [ebx-1+4]	; EAX := __NR_write == 4.
		push ebx
		mov ecx, message	; Pointer to message string.
		lea edx, [ebx-1+message.end-message]  ; EDX := Size of message to write.
		int 0x80		; Linux i386 syscall.
		;mov eax, 1		; __NR_exit.
		pop eax			; EAX := 1 == __NR_exit.
		;mov ebx, 0		; EXIT_SUCCESS.
		dec ebx			; EBX := 0 == EXIT_SUCCESS.
		int 0x80		; Linux i386 syscall.
%else  ; Hack for 16-bit assemblers such as mininasm.
		bits 16
		cpu 8086
		xor bx, bx		; xor ebx, ebx
		inc bx			; inc ebx
		lea ax, [bp+di-1+4]	; lea eax, [ebx-1+4]
		push bx			; push ebx
		db 0xb9
		dd message		; mov ecx, message
		lea dx, [bp+di-1+message.end-message]  ; lea edx, [ebx-1+messag.end-message]
		int 0x80		; int 0x80
		pop ax			; pop eax
		dec bx			; dec ebx
		int 0x80		; int 0x80
%endif
		; Not reached.

message:	db 'Hello, World!', 10
.end:

filesize	equ $-$$
