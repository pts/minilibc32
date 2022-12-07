;
; hello_min.nasm: minimalistic hello-world for Linux i386
; by pts@fazekas.hu at Wed Dec  7 04:13:28 CET 2022
;
; Compile: nasm -O0 -f bin -o hello_min hello_min.nasm && chmod +x hello_min
; The created executable program is 123 bytes.
; Run on Linux i386 or amd64: ./hello_min
;
; ELF32 header based on
; https://www.muppetlabs.com/~breadbox/software/tiny/teensy.html
;
; To the best knowledge of the author this is the shortest Linux i386
; executable program doing hello-world without overlapping the code and data
; with the ELF32 headers.
;

		bits 32
		cpu 386
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
		dw ehdrsize		;   e_ehsize
		dw phdrsize		;   e_phentsize
		dw 1			;   e_phnum
		dw 0			;   e_shentsize
		dw 40			;   e_shnum
		dw 0			;   e_shstrndx
  
ehdrsize	equ $-ehdr
phdr:					; Elf32_Phdr
		dd 1			;   p_type
		dd 0			;   p_offset
		dd $$			;   p_vaddr
		dd $$			;   p_paddr
		dd filesize		;   p_filesz
		dd filesize		;   p_memsz
		dd 5			;   p_flags
		dd 0x1000		;   p_align
phdrsize	equ $-phdr

_start:		mov eax, 4		; __NR_write.
		;mov ebx, 1		; STDOUT_FILENO.
		xor ebx, ebx
		inc ebx
		push ebx
		mov ecx, message	; Pointer to message string.
		mov edx, message.end-message  ; Size of message to write.
		int 0x80		; Linux i386 syscall.
		;mov eax, 1		; __NR_exit.
		pop eax
		;mov ebx, 0		; EXIT_SUCCESS.
		dec ebx
		int 0x80		; Linux i386 syscall.
		; Not reached.

message:	db 'Hello, World!', 10
.end:
  
filesize	equ $-$$
