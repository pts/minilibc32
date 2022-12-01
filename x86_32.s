/**/
/*
 * x86_32.s: test file for as2nasm.pl, in GNU as (AT&T) syntax
 * by pts@fazekas.hu at Mon Nov 28 18:18:47 CET 2022
 *
 * Compiles with GNU as 2.30: as -32 -march=core2+3dnow --fatal-warnings -o x86_32a.o x86_32.s
 * Compiles with GNU as 2.30: as -32 --fatal-warnings -o x86_32a.o x86_32.s
 * Try: as -32 -march=core2+3dnow --fatal-warnings -o x86_32a.o x86_32.s && ld -s -m elf_i386 -o x86_32a x86_32a.o && ./x86_32a && echo OK
 */
.text

.globl _start
_start:
		xor %eax, %eax
		inc %eax		/* __NR_exit on Linux. */
		xor %ebx, %ebx		/* EXIT_SUCCESS. */
.Lexit:  /* This label will omitted by GNU as from the .o file, because it starts with .L */
		int $0x80		/* syscall(...) on Linux. */

		addb $4, _end+5(%ecx,%edx,4)
		addw $5, _end+5(%ecx,%edx,4)
		addl $6, _end+5(%ecx,%edx,4)
		addb $7, _end+5(%ebx)
		addw $8, _end+5(%ebx)
		addl $9, _end+5(%ebx)
		add $10, %al
		add $11, %ax
		add $12, %eax
		addb $13, %al
		addw $14, %ax
		addl $15, %eax
		fiadds (%ebx)
		fiadds (%ebx)  /* fiaddw (%ebx)  ; as2nasm supports it, GNU as supports only fiadds. */
		fiaddl (%ebx)

/* Minimum: cpu 386 */

		incb   %cs:(%ebx)
		incb   %cs:0x2a(%ecx,%edx,4)
		ds
		incb   %ds:(%ebx)
		ds  /* Because GNU as (but not NASM) optimizes away the %ds: prefix in the next line. */
		incb   %ds:0x2a(%ecx,%edx,4)
		incb   %es:(%ebx)
		incb   %es:0x2a(%ecx,%edx,4)
		incb   %fs:(%ebx)
		incb   %fs:0x2a(%ecx,%edx,4)
		incb   %gs:(%ebx)
		incb   %gs:0x2a(%ecx,%edx,4)
		incb   %ss:(%ebx)
		incb   %ss:0x2a(%ecx,%edx,4)
		incb   %cs:(%ebx)
		incb   %cs:0x2a(%ecx,%edx,4)

		lock incb (%ebx)
		lock incb 0x2a(%ecx,%edx,4)
		fwait
		incb   (%ebx)
		fwait
		incb   0x2a(%ecx,%edx,4)

		rep movsb %ds:(%esi),%es:(%edi)
		repz cmpsb %es:(%edi),%ds:(%esi)
		repnz  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		cmpsw %es:(%edi),%ds:(%esi)
		repz scas %es:(%edi),%eax
		repnz scas %es:(%edi),%al
		repz
		scas %es:(%edi),%ax  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		repz cmpsl %es:(%edi),%ds:(%esi)
		rep insb (%dx),%es:(%edi)
		rep  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		insw (%dx),%es:(%edi)
		rep insl (%dx),%es:(%edi)
		rep lods %ds:(%esi),%al
		rep  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		lods %ds:(%esi),%ax
		rep lods %ds:(%esi),%eax
		rep  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		movsw %ds:(%esi),%es:(%edi)
		rep movsl %ds:(%esi),%es:(%edi)
		rep outsb %ds:(%esi),(%dx)
		rep  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		outsw %ds:(%esi),(%dx)
		rep outsl %ds:(%esi),(%dx)
		rep outsb %ds:(%esi),(%dx)
		rep  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		stos %ax,%es:(%edi)
		rep stos %eax,%es:(%edi)
		rep stos %eax,%es:(%edi)

		rep movsb
		repz cmpsb
		repnz  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		cmpsw
		repz scasb
		repnz  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		scasw
		repz scasl
		repz cmpsl
		rep insb
		rep
		insw  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		rep insl
		rep lodsb
		rep  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		lodsw
		rep lodsl
		rep  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		movsw
		rep movsl
		rep outsb
		rep  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		outsw
		rep outsl
		rep outsb
		rep stosb
		rep
		stosw  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		rep stosl

		incb   %cs:(%ebx)
		incb   %cs:0x2a(%ecx,%edx,4)
		ds  /* Because GNU as (but not NASM) optimizes away the %ds: prefix in the next line. */
		incb   %ds:(%ebx)
		ds  /* Because GNU as (but not NASM) optimizes away the %ds: prefix in the next line. */
		incb   %ds:0x2a(%ecx,%edx,4)
		incb   %es:(%ebx)
		incb   %es:0x2a(%ecx,%edx,4)
		incb   %fs:(%ebx)
		incb   %fs:0x2a(%ecx,%edx,4)
		incb   %gs:(%ebx)
		incb   %gs:0x2a(%ecx,%edx,4)
		lock incb (%ebx)
		lock incb 0x2a(%ecx,%edx,4)
		/*repz incb (%ebx)*/
		/*repz incb 0x2a(%ecx,%edx,4)*/
		/*repz incb (%ebx)*/
		/*repz incb 0x2a(%ecx,%edx,4)*/
		/*repnz incb (%ebx)*/
		/*repnz incb 0x2a(%ecx,%edx,4)*/
		/*repnz incb (%ebx)*/
		/*repnz incb 0x2a(%ecx,%edx,4)*/
		/*repz incb (%ebx)*/
		/*repz incb 0x2a(%ecx,%edx,4)*/
		incb   %ss:(%ebx)
		incb   %ss:0x2a(%ecx,%edx,4)
		fwait
		incb   (%ebx)
		fwait
		incb   0x2a(%ecx,%edx,4)
		wait nop
		fwait

		aaa    
		aad    $0xa
		aam    $0xa
		aas    
		cbtw
		cltd
		clc    
		cld    
		cli    
		clts   
		cmc    
		cmpsb  %es:(%edi),%ds:(%esi)
		cmpsw  %es:(%edi),%ds:(%esi)
		cmpsl  %es:(%edi),%ds:(%esi)
		cmpsl  %es:(%edi),%ds:(%esi)
		cwtd
		cwtl
		daa    
		das    
		f2xm1  
		fabs   
		fadd   %st,%st(1)
		faddp  %st,%st(1)
		faddp  %st,%st(1)
		fchs   
		fclex  
		fcom   %st(1)
		fcomp  %st(1)
		fcom   %st(1)
		fcomp  %st(1)
		fcompp 
		fcos   
		fdecstp 
		fdivrp %st,%st(1)
		fdivrp %st,%st(1)
		fdivp  %st,%st(1)
		fdivp  %st,%st(1)
		ffree  %st(1)
		ffreep %st(1)
		fincstp 
		finit  
		fld    %st(1)
		fld1   
		fldl2e 
		fldl2t 
		fldlg2 
		fldln2 
		fldpi  
		fldz   
		fmulp  %st,%st(1)
		fmulp  %st,%st(1)
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
		fst    %st(1)
		fstp   %st(1)
		fsubrp %st,%st(1)
		fsubrp %st,%st(1)
		fsubp  %st,%st(1)
		fsubp  %st,%st(1)
		ftst   
		fucom  %st(1)
		fucomp %st(1)
		fucompp 
		fxam   
		fxch   %st(1)
		fxtract 
		fyl2x  
		fyl2xp1 
		hlt    
		insb   (%dx),%es:(%edi)
		insw   (%dx),%es:(%edi)
		insl   (%dx),%es:(%edi)
		int3   
		into   
		iret   
		iretw  
		iret   
		lahf   
		leave  
		lods   %ds:(%esi),%al
		lods   %ds:(%esi),%ax
		lods   %ds:(%esi),%eax
		movsb  %ds:(%esi),%es:(%edi)
		movsw  %ds:(%esi),%es:(%edi)
		movsl  %ds:(%esi),%es:(%edi)
		movsl  %ds:(%esi),%es:(%edi)
		nop
		outsb  %ds:(%esi),(%dx)
		outsw  %ds:(%esi),(%dx)
		outsl  %ds:(%esi),(%dx)
		pause  
		popa   
		popaw  
		popa   
		popf   
		popfw  
		popf   
		pusha  
		pushaw 
		pusha  
		pushf  
		pushfw 
		pushf  
		ret    
		sahf   
		scas   %es:(%edi),%al
		scas   %es:(%edi),%ax
		scas   %es:(%edi),%eax
		stc    
		std    
		sti    
		stos   %al,%es:(%edi)
		stos   %ax,%es:(%edi)
		stos   %eax,%es:(%edi)
		ud2    
		/*ud2b*/  /* NASM and GNU as encode this differently. */
		/*ud2a*/
		/*ud2b*/
		xlat
		xlatb
		aad    $1
		aam    $0x1
		call   .Lhere
		int    $0x1
.Lhere:		ja .Lhere
		jae .Lhere
		jb .Lhere
		jbe .Lhere
		jc .Lhere
		jcxz .Lhere
		je .Lhere
		jecxz .Lhere
		jg .Lhere
		jge .Lhere
		jl .Lhere
		jle .Lhere
		jmp .Lhere
		jna .Lhere
		jnae .Lhere
		jnb .Lhere
		jnbe .Lhere
		jnc .Lhere
		jne .Lhere
		jng .Lhere
		jnge .Lhere
		jnl .Lhere
		jnle .Lhere
		jno .Lhere
		jnp .Lhere
		jns .Lhere
		jnz .Lhere
		jo .Lhere
		jp .Lhere
		jpe .Lhere
		jpo .Lhere
		js .Lhere
		jz .Lhere
		loop .Lhere
		loope .Lhere
		loopne .Lhere
		loopnz .Lhere
		loopz .Lhere
		push   $0x1
		ret    $0x1
		call   *%eax
		dec    %eax
		div    %eax
		idiv   %eax
		imul   %eax
		inc    %eax
		jmp    *%eax
		mul    %eax
		neg    %eax
		not    %eax
		pop    %eax
		push   %eax
		sldt   %eax
		smsw   %eax
		str    %eax
		adc    %ebx,%eax
		add    %ebx,%eax
		and    %ebx,%eax
		bsf    %ebx,%eax
		bsr    %ebx,%eax
		bt     %ebx,%eax
		btc    %ebx,%eax
		btr    %ebx,%eax
		bts    %ebx,%eax
		cmp    %ebx,%eax
		imul   %ebx,%eax
		lar    %bx,%eax
		lsl    %bx,%eax
		mov    %ebx,%eax
		or     %ebx,%eax
		sbb    %ebx,%eax
		sub    %ebx,%eax
		test   %ebx,%eax
		xchg   %eax,%ebx
		xor    %ebx,%eax
		dec    %al
		div    %al
		idiv   %al
		imul   %al
		inc    %al
		mul    %al
		neg    %al
		not    %al
		seta   %al
		setae  %al
		setb   %al
		setbe  %al
		setb   %al
		sete   %al
		setg   %al
		setge  %al
		setl   %al
		setle  %al
		setbe  %al
		setb   %al
		setae  %al
		seta   %al
		setae  %al
		setne  %al
		setle  %al
		setl   %al
		setge  %al
		setg   %al
		setno  %al
		setnp  %al
		setns  %al
		setne  %al
		seto   %al
		setp   %al
		setp   %al
		setnp  %al
		sets   %al
		sete   %al
		adc    $0x1,%eax
		add    $0x1,%eax
		and    $0x1,%eax
		bt     $0x1,%eax
		btc    $0x1,%eax
		btr    $0x1,%eax
		bts    $0x1,%eax
		cmp    $0x1,%eax
		imul   $0x1,%eax,%eax
		in     $0x1,%eax
		mov    $0x1,%eax
		or     $0x1,%eax
		rcl    %eax
		rcr    %eax
		rol    %eax
		ror    %eax
		shl    %eax
		sar    %eax
		sbb    $0x1,%eax
		shl    %eax
		shr    %eax
		sub    $0x1,%eax
		test   $0x1,%eax
		xor    $0x1,%eax
		call   *(%ebx)
		call   *0x2a(%ecx,%edx,4)
		fbld   (%ebx)
		fbld   0x2a(%ecx,%edx,4)
		fbstp  (%ebx)
		fbstp  0x2a(%ecx,%edx,4)
		fldcw  (%ebx)
		fldcw  0x2a(%ecx,%edx,4)
		fldenv (%ebx)
		fldenv 0x2a(%ecx,%edx,4)
		fnsave (%ebx)
		fnsave 0x2a(%ecx,%edx,4)
		fnstcw (%ebx)
		fnstcw 0x2a(%ecx,%edx,4)
		fnstenv (%ebx)
		fnstenv 0x2a(%ecx,%edx,4)
		fnstsw (%ebx)
		fnstsw 0x2a(%ecx,%edx,4)
		frstor (%ebx)
		frstor 0x2a(%ecx,%edx,4)
		fsave  (%ebx)
		fsave  0x2a(%ecx,%edx,4)
		fstcw  (%ebx)
		fstcw  0x2a(%ecx,%edx,4)
		fstenv (%ebx)
		fstenv 0x2a(%ecx,%edx,4)
		fstsw  (%ebx)
		fstsw  0x2a(%ecx,%edx,4)
		jmp    *(%ebx)
		jmp    *0x2a(%ecx,%edx,4)
		lgdtl  (%ebx)
		lgdtl  0x2a(%ecx,%edx,4)
		lidtl  (%ebx)
		lidtl  0x2a(%ecx,%edx,4)
		lldt   (%ebx)
		lldt   0x2a(%ecx,%edx,4)
		lmsw   (%ebx)
		lmsw   0x2a(%ecx,%edx,4)
		ltr    (%ebx)
		ltr    0x2a(%ecx,%edx,4)
		seta   (%ebx)
		seta   0x2a(%ecx,%edx,4)
		setae  (%ebx)
		setae  0x2a(%ecx,%edx,4)
		setb   (%ebx)
		setb   0x2a(%ecx,%edx,4)
		setbe  (%ebx)
		setbe  0x2a(%ecx,%edx,4)
		setb   (%ebx)
		setb   0x2a(%ecx,%edx,4)
		sete   (%ebx)
		sete   0x2a(%ecx,%edx,4)
		setg   (%ebx)
		setg   0x2a(%ecx,%edx,4)
		setge  (%ebx)
		setge  0x2a(%ecx,%edx,4)
		setl   (%ebx)
		setl   0x2a(%ecx,%edx,4)
		setle  (%ebx)
		setle  0x2a(%ecx,%edx,4)
		setbe  (%ebx)
		setbe  0x2a(%ecx,%edx,4)
		setb   (%ebx)
		setb   0x2a(%ecx,%edx,4)
		setae  (%ebx)
		setae  0x2a(%ecx,%edx,4)
		seta   (%ebx)
		seta   0x2a(%ecx,%edx,4)
		setae  (%ebx)
		setae  0x2a(%ecx,%edx,4)
		setne  (%ebx)
		setne  0x2a(%ecx,%edx,4)
		setle  (%ebx)
		setle  0x2a(%ecx,%edx,4)
		setl   (%ebx)
		setl   0x2a(%ecx,%edx,4)
		setge  (%ebx)
		setge  0x2a(%ecx,%edx,4)
		setg   (%ebx)
		setg   0x2a(%ecx,%edx,4)
		setno  (%ebx)
		setno  0x2a(%ecx,%edx,4)
		setnp  (%ebx)
		setnp  0x2a(%ecx,%edx,4)
		setns  (%ebx)
		setns  0x2a(%ecx,%edx,4)
		setne  (%ebx)
		setne  0x2a(%ecx,%edx,4)
		seto   (%ebx)
		seto   0x2a(%ecx,%edx,4)
		setp   (%ebx)
		setp   0x2a(%ecx,%edx,4)
		setp   (%ebx)
		setp   0x2a(%ecx,%edx,4)
		setnp  (%ebx)
		setnp  0x2a(%ecx,%edx,4)
		sets   (%ebx)
		sets   0x2a(%ecx,%edx,4)
		sete   (%ebx)
		sete   0x2a(%ecx,%edx,4)
		sgdtl  (%ebx)
		sgdtl  0x2a(%ecx,%edx,4)
		sidtl  (%ebx)
		sidtl  0x2a(%ecx,%edx,4)
		sldt   (%ebx)
		sldt   0x2a(%ecx,%edx,4)
		smsw   (%ebx)
		smsw   0x2a(%ecx,%edx,4)
		str    (%ebx)
		str    0x2a(%ecx,%edx,4)
		verr   (%ebx)
		verr   0x2a(%ecx,%edx,4)
		verw   (%ebx)
		verw   0x2a(%ecx,%edx,4)
		adc    (%ebx),%eax
		adc    0x2a(%ecx,%edx,4),%eax
		add    (%ebx),%eax
		add    0x2a(%ecx,%edx,4),%eax
		and    (%ebx),%eax
		and    0x2a(%ecx,%edx,4),%eax
		bound  %eax,(%ebx)
		bound  %eax,0x2a(%ecx,%edx,4)
		bsf    (%ebx),%eax
		bsf    0x2a(%ecx,%edx,4),%eax
		bsr    (%ebx),%eax
		bsr    0x2a(%ecx,%edx,4),%eax
		cmp    (%ebx),%eax
		cmp    0x2a(%ecx,%edx,4),%eax
		imul   (%ebx),%eax
		imul   0x2a(%ecx,%edx,4),%eax
		lar    (%ebx),%eax
		lar    0x2a(%ecx,%edx,4),%eax
		lds    (%ebx),%eax
		lds    0x2a(%ecx,%edx,4),%eax
		lea    (%ebx),%eax
		lea    0x2a(%ecx,%edx,4),%eax
		les    (%ebx),%eax
		les    0x2a(%ecx,%edx,4),%eax
		lfs    (%ebx),%eax
		lfs    0x2a(%ecx,%edx,4),%eax
		lgs    (%ebx),%eax
		lgs    0x2a(%ecx,%edx,4),%eax
		lsl    (%ebx),%eax
		lsl    0x2a(%ecx,%edx,4),%eax
		lss    (%ebx),%eax
		lss    0x2a(%ecx,%edx,4),%eax
		mov    (%ebx),%eax
		mov    0x2a(%ecx,%edx,4),%eax
		or     (%ebx),%eax
		or     0x2a(%ecx,%edx,4),%eax
		sbb    (%ebx),%eax
		sbb    0x2a(%ecx,%edx,4),%eax
		sub    (%ebx),%eax
		sub    0x2a(%ecx,%edx,4),%eax
		test   %eax,(%ebx)
		test   %eax,0x2a(%ecx,%edx,4)
		xchg   %eax,(%ebx)
		xchg   %eax,0x2a(%ecx,%edx,4)
		xor    (%ebx),%eax
		xor    0x2a(%ecx,%edx,4),%eax
		fiadds (%ebx)
		fiadds 0x2a(%ecx,%edx,4)
		ficoms (%ebx)
		ficoms 0x2a(%ecx,%edx,4)
		ficomps (%ebx)
		ficomps 0x2a(%ecx,%edx,4)
		fidivs (%ebx)
		fidivs 0x2a(%ecx,%edx,4)
		fidivrs (%ebx)
		fidivrs 0x2a(%ecx,%edx,4)
		filds  (%ebx)
		filds  0x2a(%ecx,%edx,4)
		fimuls (%ebx)
		fimuls 0x2a(%ecx,%edx,4)
		fists  (%ebx)
		fists  0x2a(%ecx,%edx,4)
		fistps (%ebx)
		fistps 0x2a(%ecx,%edx,4)
		fisubs (%ebx)
		fisubs 0x2a(%ecx,%edx,4)
		fisubrs (%ebx)
		fisubrs 0x2a(%ecx,%edx,4)
		movsbl %bl,%eax
		movsbl (%ebx),%eax
		movswl (%ebx),%eax
		movzbl %bl,%eax
		shld   $0x1,%ebx,%eax
		shrd   $0x1,%ebx,%eax
		arpl   %bx,%ax
		enter  $0xffff,$0xff
		out    %eax,$0x1
		out    %eax,(%dx)
		out    %ax,(%dx)
		in     $0x1,%eax
		in     (%dx),%eax
		in     (%dx),%ax
		shld   %cl,%ebx,%eax
		shrd   %cl,%ebx,%eax
		shld   $0x3f,%ebx,%eax
		shrd   $0x3f,%ebx,%eax
		shl    %cl,%eax
		shr    %cl,%eax
		shl    $0x1f,%eax
		shr    $0x1f,%eax
		rep movsb %ds:(%esi),%es:(%edi)
		repnz  /* Separating this prefix from the next word-size string instruction to match NASM. Without the separation GNU as would generate the `db 0x66' word size prefix first. */
		cmpsw %es:(%edi),%ds:(%esi)
		repz scas %es:(%edi),%eax
		imul   $0x7f,%bx,%ax
		imul   $0x7f,%ebx,%eax
		imul   $0xffff,%bx,%ax
		imul   $0x7fffffff,%ebx,%eax
		lcall  $0xface,$0xdeadbeef
		ljmp   $0xface,$0xdeadbeef

/* Minimum: cpu 486 */

		invd   
		wbinvd 
		bswap  %eax
		xadd   %ebx,%eax
		invlpg (%ebx)
		invlpg 0x2a(%ecx,%edx,4)

/* Minimum: cpu 586 */

		cpuid  
		femms  /* Requires: -march=...+3dnow */  
		rdmsr  
		rdtsc  
		rsm    
		wrmsr  
		cmpxchg %ebx,%eax
		cmpxchg8b (%ebx)
		cmpxchg8b 0x2a(%ecx,%edx,4)
		prefetch (%ebx)
		prefetch 0x2a(%ecx,%edx,4)
		prefetchw (%ebx)
		prefetchw 0x2a(%ecx,%edx,4)
		prefetchw (%ebx)
		prefetchw 0x2a(%ecx,%edx,4)

/* Minimum: cpu 686 */

		fcmovb %st(1),%st
		fcmovbe %st(1),%st
		fcmove %st(1),%st
		fcmovnb %st(1),%st
		fcmovnbe %st(1),%st
		fcmovne %st(1),%st
		fcmovnu %st(1),%st
		fcmovu %st(1),%st
		fcomi  %st(1),%st
		fcomip %st(1),%st
		fucomi %st(1),%st
		fucomip %st(1),%st
		rdpmc  
		syscall 
		sysenter 
		sysexit 
		sysret 
		nop    %eax         /* NASM 0.98.39 doesn't support it. */
		nopl    %ebx        /* NASM 0.98.39 doesn't support it. */
		nopw %bx            /* NASM 0.98.39 doesn't support it. */
		/*nopl (%ecx,%edx,2)*/  /* NASM 0.98.39 doesn't support it. */
		/*nopw (%ecx,%edx,2)*/  /* NASM 0.98.39 doesn't support it. */
		cmova  %ebx,%eax
		cmovae %ebx,%eax
		cmovb  %ebx,%eax
		cmovbe %ebx,%eax
		cmovb  %ebx,%eax
		cmove  %ebx,%eax
		cmovg  %ebx,%eax
		cmovge %ebx,%eax
		cmovl  %ebx,%eax
		cmovle %ebx,%eax
		cmovbe %ebx,%eax
		cmovb  %ebx,%eax
		cmovae %ebx,%eax
		cmova  %ebx,%eax
		cmovae %ebx,%eax
		cmovne %ebx,%eax
		cmovle %ebx,%eax
		cmovl  %ebx,%eax
		cmovge %ebx,%eax
		cmovg  %ebx,%eax
		cmovno %ebx,%eax
		cmovnp %ebx,%eax
		cmovns %ebx,%eax
		cmovne %ebx,%eax
		cmovo  %ebx,%eax
		cmovp  %ebx,%eax
		cmovs  %ebx,%eax
		cmove  %ebx,%eax
		fxrstor (%ebx)
		fxrstor 0x2a(%ecx,%edx,4)
		fxsave (%ebx)
		fxsave 0x2a(%ecx,%edx,4)
		cmova  (%ebx),%eax
		cmova  0x2a(%ecx,%edx,4),%eax
		cmovae (%ebx),%eax
		cmovae 0x2a(%ecx,%edx,4),%eax
		cmovb  (%ebx),%eax
		cmovb  0x2a(%ecx,%edx,4),%eax
		cmovbe (%ebx),%eax
		cmovbe 0x2a(%ecx,%edx,4),%eax
		cmovb  (%ebx),%eax
		cmovb  0x2a(%ecx,%edx,4),%eax
		cmove  (%ebx),%eax
		cmove  0x2a(%ecx,%edx,4),%eax
		cmovg  (%ebx),%eax
		cmovg  0x2a(%ecx,%edx,4),%eax
		cmovge (%ebx),%eax
		cmovge 0x2a(%ecx,%edx,4),%eax
		cmovl  (%ebx),%eax
		cmovl  0x2a(%ecx,%edx,4),%eax
		cmovle (%ebx),%eax
		cmovle 0x2a(%ecx,%edx,4),%eax
		cmovbe (%ebx),%eax
		cmovbe 0x2a(%ecx,%edx,4),%eax
		cmovb  (%ebx),%eax
		cmovb  0x2a(%ecx,%edx,4),%eax
		cmovae (%ebx),%eax
		cmovae 0x2a(%ecx,%edx,4),%eax
		cmova  (%ebx),%eax
		cmova  0x2a(%ecx,%edx,4),%eax
		cmovae (%ebx),%eax
		cmovae 0x2a(%ecx,%edx,4),%eax
		cmovne (%ebx),%eax
		cmovne 0x2a(%ecx,%edx,4),%eax
		cmovle (%ebx),%eax
		cmovle 0x2a(%ecx,%edx,4),%eax
		cmovl  (%ebx),%eax
		cmovl  0x2a(%ecx,%edx,4),%eax
		cmovge (%ebx),%eax
		cmovge 0x2a(%ecx,%edx,4),%eax
		cmovg  (%ebx),%eax
		cmovg  0x2a(%ecx,%edx,4),%eax
		cmovno (%ebx),%eax
		cmovno 0x2a(%ecx,%edx,4),%eax
		cmovnp (%ebx),%eax
		cmovnp 0x2a(%ecx,%edx,4),%eax
		cmovns (%ebx),%eax
		cmovns 0x2a(%ecx,%edx,4),%eax
		cmovne (%ebx),%eax
		cmovne 0x2a(%ecx,%edx,4),%eax
		cmovo  (%ebx),%eax
		cmovo  0x2a(%ecx,%edx,4),%eax
		cmovp  (%ebx),%eax
		cmovp  0x2a(%ecx,%edx,4),%eax
		cmovs  (%ebx),%eax
		cmovs  0x2a(%ecx,%edx,4),%eax
		cmove  (%ebx),%eax
		cmove  0x2a(%ecx,%edx,4),%eax

/* Minimum: more than: cpu >686 */

		lfence 
		mfence 
		monitor %eax,%ecx,%edx
		mwait  %eax,%ecx
		sfence 
		clflush (%ebx)
		clflush 0x2a(%ecx,%edx,4)
		ldmxcsr (%ebx)
		ldmxcsr 0x2a(%ecx,%edx,4)
		prefetchnta (%ebx)
		prefetchnta 0x2a(%ecx,%edx,4)
		prefetcht0 (%ebx)
		prefetcht0 0x2a(%ecx,%edx,4)
		prefetcht1 (%ebx)
		prefetcht1 0x2a(%ecx,%edx,4)
		prefetcht2 (%ebx)
		prefetcht2 0x2a(%ecx,%edx,4)
		stmxcsr (%ebx)
		stmxcsr 0x2a(%ecx,%edx,4)
		fisttpll (%ebx)
		/*fisttpll 0x2a(%ecx,%edx,4)*/  /* NASM 0.98.39 is bugy: it generates the wrong size. */
		fisttpl (%ebx)
		/*fisttpl 0x2a(%ecx,%edx,4)*/  /* NASM 0.98.39 is bugy: it generates the wrong size. */
		fisttps (%ebx)
		/*fisttps 0x2a(%ecx,%edx,4)*/  /* NASM 0.98.39 is bugy: it generates the wrong size. */
		movnti %eax,(%ebx)
		movnti %eax,0x2a(%ecx,%edx,4)

_end:
/* __END__ */
