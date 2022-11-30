;
; x86_32.nasm: test file for as2nasm.pl, in NASM 0.98.39 syntax
; by pts@fazekas.hu at Mon Nov 28 18:18:47 CET 2022
;
; Compiles with NASM 0.98.39 and NASM 2.13.02: nasm -O9 -f elf -o x86_32.o x86_32.nasm
; Try: nasm -O9 -f elf -o x86_32.o x86_32.nasm && ld -s -m elf_i386 -o x86_32 x86_32.o && ./x86_32 && echo OK
;

		bits 32
		;cpu 386
		section .text align=4

global _start
_start:		xor eax, eax
		inc eax			; __NR_exit on Linux.
		xor ebx, ebx		; EXIT_SUCCESS.
.Lexit:	 ; It's not possible to hide labels from `nasm -f elf' output, `nm' will show them, e.g. this one as _start.Lexit.
		int 0x80		; syscall(...) on Linux.

		add byte [_end+5+ecx+edx*4], 4
		add word [_end+5+ecx+edx*4], 5
		add dword [_end+5+ecx+edx*4], 6
		add byte [_end+5+ebx], 7
		add word [_end+5+ebx], 8
		add dword [_end+5+ebx], 9
		add al, 10
		add ax, 11
		add eax, 12
		add al, 13
		add ax, 14
		add eax, 15
		fiadd word [ebx]
		fiadd word [ebx]
		fiadd dword [ebx]

; Minimum: cpu 386

		inc byte [cs:ebx]
		inc byte [cs:ecx+edx*4+42]
		inc byte [ds:ebx]
		inc byte [ds:ecx+edx*4+42]
		inc byte [es:ebx]
		inc byte [es:ecx+edx*4+42]
		inc byte [fs:ebx]
		inc byte [fs:ecx+edx*4+42]
		inc byte [gs:ebx]
		inc byte [gs:ecx+edx*4+42]
		inc byte [ss:ebx]
		inc byte [ss:ecx+edx*4+42]
		inc byte [cs:ebx]
		inc byte [cs:ecx+edx*4+42]

		lock inc byte [ebx]
		lock inc byte [ecx+edx*4+42]
		wait  ; NASM 0.98.39 doesn't allow wait as prefix.
		inc byte [ebx]
		wait  ; NASM 0.98.39 doesn't allow wait as prefix.
		inc byte [ecx+edx*4+42]

		rep movsb
		repe cmpsb
		repne cmpsw
		repz scasd
		repnz scasb
		repe scasw
		rep cmpsd
		rep insb
		rep insw
		rep insd
		rep lodsb
		rep lodsw
		rep lodsd
		rep movsw
		rep movsd
		rep outsb
		rep outsw
		rep outsd
		rep outsb
		rep stosw
		rep stosd
		rep stosd

		rep movsb
		repz cmpsb
		repnz cmpsw
		repz scasb
		repnz scasw
		repz scasd
		repz cmpsd
		rep insb
		rep insw
		rep insd
		rep lodsb
		rep lodsw
		rep lodsd
		rep movsw
		rep movsd
		rep outsb
		rep outsw
		rep outsd
		rep outsb
		rep stosb
		rep stosw
		rep stosd

		cs inc byte [ebx]
		cs inc byte [ecx+edx*4+42]
		ds inc byte [ebx]
		ds inc byte [ecx+edx*4+42]
		es inc byte [ebx]
		es inc byte [ecx+edx*4+42]
		fs inc byte [ebx]
		fs inc byte [ecx+edx*4+42]
		gs inc byte [ebx]
		gs inc byte [ecx+edx*4+42]
		lock inc byte [ebx]
		lock inc byte [ecx+edx*4+42]
		;rep inc byte [ebx]
		;rep inc byte [ecx+edx*4+42]
		;repe inc byte [ebx]
		;repe inc byte [ecx+edx*4+42]
		;repne inc byte [ebx]
		;repne inc byte [ecx+edx*4+42]
		;repnz inc byte [ebx]
		;repnz inc byte [ecx+edx*4+42]
		;repz inc byte [ebx]
		;repz inc byte [ecx+edx*4+42]
		ss inc byte [ebx]
		ss inc byte [ecx+edx*4+42]
		wait  ; NASM 0.98.39 doesn't allow wait as prefix.
		inc byte [ebx]
		wait  ; NASM 0.98.39 doesn't allow wait as prefix.
		inc byte [ecx+edx*4+42]
		wait  ; NASM 0.98.39 doesn't allow wait as prefix.
		nop
		fwait  ; Same byte as `wait', but not a prefix in NASM.

		aaa
		aad
		aam
		aas
		cbw
		cdq
		clc
		cld
		cli
		clts
		cmc
		cmpsb
		cmpsw
		cmpsd
		cmpsd
		cwd
		cwde
		daa
		das
		f2xm1
		fabs
		fadd  st1, st0
		faddp st1, st0  ; Same as `fadd' and `faddp' without arguments, but NASM 0.98.39 doesn't support those.
		faddp st1, st0
		fchs
		fclex
		fcom  st1
		fcomp st1
		fcom  st1  ; fcom  ; NASM 0.98.39 doesn't support it.
		fcomp st1  ; fcomp ; NASM 0.98.39 doesn't support it.
		fcompp
		fcos
		fdecstp
		fdivp  st1, st0  ; fdiv    ; NASM 0.98.39 doesn't support it.
		fdivp  st1, st0  ; fdivp   ; NASM 0.98.39 doesn't support it.
		fdivrp st1, st0  ; fdivr   ; NASM 0.98.39 doesn't support it.
		fdivrp st1, st0  ; fdivrp  ; NASM 0.98.39 doesn't support it.
		ffree st1   ; ffree   ; NASM 0.98.39 doesn't support it.
		ffreep st1  ; ffreep  ; NASM 0.98.39 doesn't support it.
		fincstp
		finit
		fld st1  ; fld  ; NASM 0.98.39 doesn't support it.
		fld1
		fldl2e
		fldl2t
		fldlg2
		fldln2
		fldpi
		fldz
		fmulp st1, st0  ; fmul   ; NASM 0.98.39 doesn't support it.
		fmulp st1, st0  ; fmulp  ; NASM 0.98.39 doesn't support it.
		fnclex
		fninit
		fnop
		fpatan
		fprem
		fprem1
		fptan
		frndint
		fscale
		fsin
		fsincos
		fsqrt
		fst  st1  ; fst   ; NASM 0.98.39 doesn't support it.
		fstp st1  ; fstp  ; NASM 0.98.39 doesn't support it.
		fsubp  st1, st0  ; fsub    ; NASM 0.98.39 doesn't support it.
		fsubp  st1, st0  ; fsubp   ; NASM 0.98.39 doesn't support it.
		fsubrp st1, st0  ; fsubr   ; NASM 0.98.39 doesn't support it.
		fsubrp st1, st0  ; fsubrp  ; NASM 0.98.39 doesn't support it.
		ftst
		fucom   st1  ; fucom   ; NASM 0.98.39 doesn't support it.
		fucomp  st1  ; fucomp  ; NASM 0.98.39 doesn't support it.
		fucompp
		fxam
		fxch
		fxtract
		fyl2x
		fyl2xp1
		hlt
		insb
		insw
		insd
		int3
		into
		iret
		iretw
		iretd
		lahf
		leave
		lodsb
		lodsw
		lodsd
		movsb
		movsw
		movsd
		movsd
		nop
		outsb
		outsw
		outsd
		pause
		popa
		popaw
		popad
		popf
		popfw
		popfd
		pusha
		pushaw
		pushad
		pushf
		pushfw
		pushfd
		ret
		sahf
		scasb
		scasw
		scasd
		stc
		std
		sti
		stosb
		stosw
		stosd
		ud2
		;ud2b
		;ud2a
		;ud2b
		xlat
		xlatb
		aad 1
		aam 1
		call .here
		int 1
.here:		ja .here
		jae .here
		jb .here
		jbe .here
		jc .here
		jcxz .here
		je .here
		jecxz .here
		jg .here
		jge .here
		jl .here
		jle .here
		jmp .here
		jna .here
		jnae .here
		jnb .here
		jnbe .here
		jnc .here
		jne .here
		jng .here
		jnge .here
		jnl .here
		jnle .here
		jno .here
		jnp .here
		jns .here
		jnz .here
		jo .here
		jp .here
		jpe .here
		jpo .here
		js .here
		jz .here
		loop .here
		loope .here
		loopne .here
		loopnz .here
		loopz .here
		push 1
		ret 1
		call eax
		dec eax
		div eax
		idiv eax
		imul eax
		inc eax
		jmp eax
		mul eax
		neg eax
		not eax
		pop eax
		push eax
		sldt eax
		smsw eax
		str eax
		adc eax, ebx
		add eax, ebx
		and eax, ebx
		bsf eax, ebx
		bsr eax, ebx
		bt eax, ebx
		btc eax, ebx
		btr eax, ebx
		bts eax, ebx
		cmp eax, ebx
		imul eax, ebx
		lar eax, ebx
		lsl eax, ebx
		mov eax, ebx
		or eax, ebx
		sbb eax, ebx
		sub eax, ebx
		test eax, ebx
		xchg eax, ebx
		xor eax, ebx
		dec al
		div al
		idiv al
		imul al
		inc al
		mul al
		neg al
		not al
		seta al
		setae al
		setb al
		setbe al
		setc al
		sete al
		setg al
		setge al
		setl al
		setle al
		setna al
		setnae al
		setnb al
		setnbe al
		setnc al
		setne al
		setng al
		setnge al
		setnl al
		setnle al
		setno al
		setnp al
		setns al
		setnz al
		seto al
		setp al
		setpe al
		setpo al
		sets al
		setz al
		adc eax, 1
		add eax, 1
		and eax, 1
		bt eax, 1
		btc eax, 1
		btr eax, 1
		bts eax, 1
		cmp eax, 1
		imul eax, 1
		in eax, 1
		mov eax, 1
		or eax, 1
		rcl eax, 1
		rcr eax, 1
		rol eax, 1
		ror eax, 1
		sal eax, 1
		sar eax, 1
		sbb eax, 1
		shl eax, 1
		shr eax, 1
		sub eax, 1
		test eax, 1
		xor eax, 1
		call [ebx]
		call [ecx+edx*4+42]
		fbld [ebx]
		fbld [ecx+edx*4+42]
		fbstp [ebx]
		fbstp [ecx+edx*4+42]
		fldcw [ebx]
		fldcw [ecx+edx*4+42]
		fldenv [ebx]
		fldenv [ecx+edx*4+42]
		fnsave [ebx]
		fnsave [ecx+edx*4+42]
		fnstcw [ebx]
		fnstcw [ecx+edx*4+42]
		fnstenv [ebx]
		fnstenv [ecx+edx*4+42]
		fnstsw [ebx]
		fnstsw [ecx+edx*4+42]
		frstor [ebx]
		frstor [ecx+edx*4+42]
		fsave [ebx]
		fsave [ecx+edx*4+42]
		fstcw [ebx]
		fstcw [ecx+edx*4+42]
		fstenv [ebx]
		fstenv [ecx+edx*4+42]
		fstsw [ebx]
		fstsw [ecx+edx*4+42]
		jmp [ebx]
		jmp [ecx+edx*4+42]
		lgdt [ebx]
		lgdt [ecx+edx*4+42]
		lidt [ebx]
		lidt [ecx+edx*4+42]
		lldt [ebx]
		lldt [ecx+edx*4+42]
		lmsw [ebx]
		lmsw [ecx+edx*4+42]
		ltr [ebx]
		ltr [ecx+edx*4+42]
		seta [ebx]
		seta [ecx+edx*4+42]
		setae [ebx]
		setae [ecx+edx*4+42]
		setb [ebx]
		setb [ecx+edx*4+42]
		setbe [ebx]
		setbe [ecx+edx*4+42]
		setc [ebx]
		setc [ecx+edx*4+42]
		sete [ebx]
		sete [ecx+edx*4+42]
		setg [ebx]
		setg [ecx+edx*4+42]
		setge [ebx]
		setge [ecx+edx*4+42]
		setl [ebx]
		setl [ecx+edx*4+42]
		setle [ebx]
		setle [ecx+edx*4+42]
		setna [ebx]
		setna [ecx+edx*4+42]
		setnae [ebx]
		setnae [ecx+edx*4+42]
		setnb [ebx]
		setnb [ecx+edx*4+42]
		setnbe [ebx]
		setnbe [ecx+edx*4+42]
		setnc [ebx]
		setnc [ecx+edx*4+42]
		setne [ebx]
		setne [ecx+edx*4+42]
		setng [ebx]
		setng [ecx+edx*4+42]
		setnge [ebx]
		setnge [ecx+edx*4+42]
		setnl [ebx]
		setnl [ecx+edx*4+42]
		setnle [ebx]
		setnle [ecx+edx*4+42]
		setno [ebx]
		setno [ecx+edx*4+42]
		setnp [ebx]
		setnp [ecx+edx*4+42]
		setns [ebx]
		setns [ecx+edx*4+42]
		setnz [ebx]
		setnz [ecx+edx*4+42]
		seto [ebx]
		seto [ecx+edx*4+42]
		setp [ebx]
		setp [ecx+edx*4+42]
		setpe [ebx]
		setpe [ecx+edx*4+42]
		setpo [ebx]
		setpo [ecx+edx*4+42]
		sets [ebx]
		sets [ecx+edx*4+42]
		setz [ebx]
		setz [ecx+edx*4+42]
		sgdt [ebx]
		sgdt [ecx+edx*4+42]
		sidt [ebx]
		sidt [ecx+edx*4+42]
		sldt [ebx]
		sldt [ecx+edx*4+42]
		smsw [ebx]
		smsw [ecx+edx*4+42]
		str [ebx]
		str [ecx+edx*4+42]
		verr [ebx]
		verr [ecx+edx*4+42]
		verw [ebx]
		verw [ecx+edx*4+42]
		adc eax, [ebx]
		adc eax, [ecx+edx*4+42]
		add eax, [ebx]
		add eax, [ecx+edx*4+42]
		and eax, [ebx]
		and eax, [ecx+edx*4+42]
		bound eax, [ebx]
		bound eax, [ecx+edx*4+42]
		bsf eax, [ebx]
		bsf eax, [ecx+edx*4+42]
		bsr eax, [ebx]
		bsr eax, [ecx+edx*4+42]
		cmp eax, [ebx]
		cmp eax, [ecx+edx*4+42]
		imul eax, [ebx]
		imul eax, [ecx+edx*4+42]
		lar eax, [ebx]
		lar eax, [ecx+edx*4+42]
		lds eax, [ebx]
		lds eax, [ecx+edx*4+42]
		lea eax, [ebx]
		lea eax, [ecx+edx*4+42]
		les eax, [ebx]
		les eax, [ecx+edx*4+42]
		lfs eax, [ebx]
		lfs eax, [ecx+edx*4+42]
		lgs eax, [ebx]
		lgs eax, [ecx+edx*4+42]
		lsl eax, [ebx]
		lsl eax, [ecx+edx*4+42]
		lss eax, [ebx]
		lss eax, [ecx+edx*4+42]
		mov eax, [ebx]
		mov eax, [ecx+edx*4+42]
		or eax, [ebx]
		or eax, [ecx+edx*4+42]
		sbb eax, [ebx]
		sbb eax, [ecx+edx*4+42]
		sub eax, [ebx]
		sub eax, [ecx+edx*4+42]
		test eax, [ebx]
		test eax, [ecx+edx*4+42]
		xchg eax, [ebx]
		xchg eax, [ecx+edx*4+42]
		xor eax, [ebx]
		xor eax, [ecx+edx*4+42]
		fiadd word [ebx]
		fiadd word [ecx+edx*4+42]
		ficom word [ebx]
		ficom word [ecx+edx*4+42]
		ficomp word [ebx]
		ficomp word [ecx+edx*4+42]
		fidiv word [ebx]
		fidiv word [ecx+edx*4+42]
		fidivr word [ebx]
		fidivr word [ecx+edx*4+42]
		fild word [ebx]
		fild word [ecx+edx*4+42]
		fimul word [ebx]
		fimul word [ecx+edx*4+42]
		fist word [ebx]
		fist word [ecx+edx*4+42]
		fistp word [ebx]
		fistp word [ecx+edx*4+42]
		fisub word [ebx]
		fisub word [ecx+edx*4+42]
		fisubr word [ebx]
		fisubr word [ecx+edx*4+42]
		movsx eax, bl
		movsx eax, byte [ebx]
		movsx eax, word [ebx]
		movzx eax, bl
		shld eax, ebx, 1
		shrd eax, ebx, 1
		arpl ax, bx
		enter 0xffff, 0xff
		out 1, eax
		out dx, eax
		out dx, ax
		in eax, 1
		in eax, dx
		in ax, dx
		shld eax, ebx, cl
		shrd eax, ebx, cl
		shld eax, ebx, 63
		shrd eax, ebx, 63
		shl eax, cl
		shr eax, cl
		shl eax, 31
		shr eax, 31
		rep movsb
		repne cmpsw
		repz scasd
		imul ax, bx, 127
		imul eax, ebx, 127
		imul ax, bx, 0xffff
		imul eax, ebx, 0x7fffffff
		call 0xface:0xdeadbeef
		jmp 0xface:0xdeadbeef

; Minimum: cpu 486

		invd
		wbinvd
		bswap eax
		xadd eax, ebx
		invlpg [ebx]
		invlpg [ecx+edx*4+42]

; Minimum: cpu 586

		cpuid
		femms
		rdmsr
		rdtsc
		rsm
		wrmsr
		cmpxchg eax, ebx
		cmpxchg8b [ebx]
		cmpxchg8b [ecx+edx*4+42]
		prefetch [ebx]
		prefetch [ecx+edx*4+42]
		prefetchw [ebx]
		prefetchw [ecx+edx*4+42]
		prefetchw [ebx]
		prefetchw [ecx+edx*4+42]

; Minimum: cpu 686

		fcmovb   st0, st1  ; fcmovb   ; NASM 0.98.39 doesn't support it.
		fcmovbe  st0, st1  ; fcmovbe  ; NASM 0.98.39 doesn't support it.
		fcmove   st0, st1  ; fcmove   ; NASM 0.98.39 doesn't support it.
		fcmovnb  st0, st1  ; fcmovnb  ; NASM 0.98.39 doesn't support it.
		fcmovnbe st0, st1  ; fcmovnbe ; NASM 0.98.39 doesn't support it.
		fcmovne  st0, st1  ; fcmovne  ; NASM 0.98.39 doesn't support it.
		fcmovnu  st0, st1  ; fcmovnu  ; NASM 0.98.39 doesn't support it.
		fcmovu   st0, st1  ; fcmovu   ; NASM 0.98.39 doesn't support it.
		fcomi    st0, st1  ; fcomi    ; NASM 0.98.39 doesn't support it.
		fcomip   st0, st1  ; fcomip   ; NASM 0.98.39 doesn't support it.
		fucomi   st0, st1  ; fucomi   ; NASM 0.98.39 doesn't support it.
		fucomip  st0, st1  ; fucomip  ; NASM 0.98.39 doesn't support it.
		rdpmc
		syscall
		sysenter
		sysexit
		sysret
		db 0x0f, 0x1f, 0xc0        ; nop eax  ; NASM 0.98.39 doesn't support it.
		db 0x0f, 0x1f, 0xc3        ; nop ebx  ; NASM 0.98.39 doesn't support it.
		db 0x66, 0x0f, 0x1f, 0xc3  ; nop bx   ; NASM 0.98.39 doesn't support it.
		;nop dword [ecx+edx*2]  ; NASM 0.98.39 doesn't support it.
		;nop word [ecx+edx*2] ; NASM 0.98.39 doesn't support it.
		cmova eax, ebx
		cmovae eax, ebx
		cmovb eax, ebx
		cmovbe eax, ebx
		cmovc eax, ebx
		cmove eax, ebx
		cmovg eax, ebx
		cmovge eax, ebx
		cmovl eax, ebx
		cmovle eax, ebx
		cmovna eax, ebx
		cmovnae eax, ebx
		cmovnb eax, ebx
		cmovnbe eax, ebx
		cmovnc eax, ebx
		cmovne eax, ebx
		cmovng eax, ebx
		cmovnge eax, ebx
		cmovnl eax, ebx
		cmovnle eax, ebx
		cmovno eax, ebx
		cmovnp eax, ebx
		cmovns eax, ebx
		cmovnz eax, ebx
		cmovo eax, ebx
		cmovp eax, ebx
		cmovs eax, ebx
		cmovz eax, ebx
		fxrstor [ebx]
		fxrstor [ecx+edx*4+42]
		fxsave [ebx]
		fxsave [ecx+edx*4+42]
		cmova eax, [ebx]
		cmova eax, [ecx+edx*4+42]
		cmovae eax, [ebx]
		cmovae eax, [ecx+edx*4+42]
		cmovb eax, [ebx]
		cmovb eax, [ecx+edx*4+42]
		cmovbe eax, [ebx]
		cmovbe eax, [ecx+edx*4+42]
		cmovc eax, [ebx]
		cmovc eax, [ecx+edx*4+42]
		cmove eax, [ebx]
		cmove eax, [ecx+edx*4+42]
		cmovg eax, [ebx]
		cmovg eax, [ecx+edx*4+42]
		cmovge eax, [ebx]
		cmovge eax, [ecx+edx*4+42]
		cmovl eax, [ebx]
		cmovl eax, [ecx+edx*4+42]
		cmovle eax, [ebx]
		cmovle eax, [ecx+edx*4+42]
		cmovna eax, [ebx]
		cmovna eax, [ecx+edx*4+42]
		cmovnae eax, [ebx]
		cmovnae eax, [ecx+edx*4+42]
		cmovnb eax, [ebx]
		cmovnb eax, [ecx+edx*4+42]
		cmovnbe eax, [ebx]
		cmovnbe eax, [ecx+edx*4+42]
		cmovnc eax, [ebx]
		cmovnc eax, [ecx+edx*4+42]
		cmovne eax, [ebx]
		cmovne eax, [ecx+edx*4+42]
		cmovng eax, [ebx]
		cmovng eax, [ecx+edx*4+42]
		cmovnge eax, [ebx]
		cmovnge eax, [ecx+edx*4+42]
		cmovnl eax, [ebx]
		cmovnl eax, [ecx+edx*4+42]
		cmovnle eax, [ebx]
		cmovnle eax, [ecx+edx*4+42]
		cmovno eax, [ebx]
		cmovno eax, [ecx+edx*4+42]
		cmovnp eax, [ebx]
		cmovnp eax, [ecx+edx*4+42]
		cmovns eax, [ebx]
		cmovns eax, [ecx+edx*4+42]
		cmovnz eax, [ebx]
		cmovnz eax, [ecx+edx*4+42]
		cmovo eax, [ebx]
		cmovo eax, [ecx+edx*4+42]
		cmovp eax, [ebx]
		cmovp eax, [ecx+edx*4+42]
		cmovs eax, [ebx]
		cmovs eax, [ecx+edx*4+42]
		cmovz eax, [ebx]
		cmovz eax, [ecx+edx*4+42]

; Minimum: more than: cpu >686

		lfence
		mfence
		monitor
		mwait
		sfence
		clflush [ebx]
		clflush [ecx+edx*4+42]
		ldmxcsr [ebx]
		ldmxcsr [ecx+edx*4+42]
		prefetchnta [ebx]
		prefetchnta [ecx+edx*4+42]
		prefetcht0 [ebx]
		prefetcht0 [ecx+edx*4+42]
		prefetcht1 [ebx]
		prefetcht1 [ecx+edx*4+42]
		prefetcht2 [ebx]
		prefetcht2 [ecx+edx*4+42]
		stmxcsr [ebx]
		stmxcsr [ecx+edx*4+42]
		db 0xdd, 0x0b              ; fisttp qword [ebx]             ; NASM 0.98.39 is buggy, it generates fisttp word ...
		;db 0xdd, 0x4c, 0x91, 0x2a  ; fisttp qword [ecx+edx*4+0x2a]  ; NASM 0.98.39 is buggy, it generates fisttp word ...
		db 0xdb, 0x0b              ; fisttp dword [ebx]             ; NASM 0.98.39 is buggy, it generates fisttp qword ...
		;db 0xdb, 0x4c, 0x91, 0x2a  ; fisttp dword [ecx+edx*4+0x2a]  ; NASM 0.98.39 is buggy, it generates fisttp qword ...
		db 0xdf, 0x0b              ; fisttp word [ebx]              ; NASM 0.98.39 is buggy, it generates fisttp dword ...
		;db 0xdf, 0x4c, 0x91, 0x2a  ; fisttp word [ecx+edx*4+0x2a]   ; NASM 0.98.39 is buggy, it generates fisttp dword ...
		movnti [ebx], eax
		movnti [ecx+edx*4+42], eax

_end:

; __END__
