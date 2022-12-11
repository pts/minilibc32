#!/bin/sh --
eval 'PERL_BADLANG=x;export PERL_BADLANG;exec perl -x "$0" "$@";exit 1'
#!perl  # Start marker used by perl -x.
+0 if 0;eval("\n\n\n\n".<<'__END__');die$@if$@;__END__

#
# as2nasm.pl: convert from i386 GNU as (AT&T) or WASM syntax, link with NASM
# by pts@fazekas.hu at Tue Nov 29 01:46:33 CET 2022
#
# !! do we need to reorder global variables by alignment (or does GCC already emit in the correct, decreasing order -- not for .comm)?
# !! doc: It's not the goal to get bitwise identical machine code output (but it's nice to have if easy), but to get same-size instructions wherever possible, maybe different encoding (e.g. `mov eax, ebx' has 2 encodings).
# !! Treat nasm warnings as errors (everything on stderr).
# !! Support `gcc -masm=intel' and `clang --x86-asm-syntax=intel'.
# !! What does it mean? .section        .text.unlikely,"ax",@progbits
# !! Ignore WASM debug info (owcc -g) in .wasm source file.
# !! Ignore GCC debug info in GNU as source files.
# !! support this (GCC 12.2 -- on non-ELF?): .bss; .align 4; myvar: .zero 4
#
# ./as2nasm.pl -march=i386 -o t.nasm mininasm.gcc75.s ^^ nasm -O19 -f elf -o t.o t.nasm && ld --fatal-warnings -s -m elf_i386 -o t.prog t.o && sstrip t.prog && ls -ld t.prog && ./t.prog
# ./as2nasm.pl -march=i386 -o t.nasm mininasm.gcc75.s && nasm -O19 -f bin -o t.prog t.nasm && chmod +x t.prog && ls -ld t.prog && ./t.prog
#

BEGIN { $^W = 1 }
use integer;
use strict;

# --- Merge C string literal by tail (e.g. merge "bar" and "foobar").

# Merge C string literal by tail (e.g. merge "bar" and "foobar").
#
# $outfh is the filehandle to write NASM assembly lines to.
#
# $rodata_strs is a reference to an array containing assembly source lines
# (`label:' and `db: ...') in `section .rodata', `section .rdata' and
# `section .rodata.str1.1' (GCC, GNU as; already
# converted to db) or `CONST SEGMENT' (OpenWatcom WASM). It will be cleared
# as a side effect.
#
# TODO(pts): Deduplicate strings in .nasm source as well.
sub print_merged_strings_in_strdata($$$) {
  my($outfh, $rodata_strs, $is_db_canonical_gnu_as) = @_;
  return if !$rodata_strs or !@$rodata_strs;
  # Test data: my $strdata_test = "foo:\ndb 'ello', 0\ndb 0\ndb 'oth'\nmer:\ndb 'er', 1\ndb 2\ndb 0\ndb 3\ndb 0\ndb 4\ndb 'hell'\nbar:\ndb 'o', 0\nbaz:\ndb 'lo', 0, 'ello', 0, 'hell', 0, 'foo', ', ', 0, 15, 3, 0\nlast:";  @$rodata_strs = split(/\n/, $strdata_test);
  my $ofs = 0;
  my @labels;
  my $strdata = "";
  for my $str (@$rodata_strs) {
    if ($str =~ m@\A\s*db\s@i) {
      pos($str) = 0;
      if ($is_db_canonical_gnu_as) {  # Shortcut.
        while ($str =~ m@\d+|'([^']*)'@g) { $ofs += defined($1) ? length($1) : 1 }
        $strdata .= $str;
        $strdata .= "\n";
      } else {
        die if $str !~ s@\A\s*db\s+@@i;
        my $str0 = $str;
        my $has_error = 0;
        # Parse and canonicalize the db string, so that we can transform it later.
        $str =~ s@(-?)0[xX]([0-9a-fA-F]+)|(-?)([0-9][0-9a-fA-F]*)[hH]|(-?)(0(?!\d)|[1-9][0-9]*)|('[^']*')|(\s*,\s*)|([^\s',]+)@
          my $v;
          if (defined($1) or defined($3) or defined($5)) {
            ++$ofs;
            $v = defined($1) ? ($1 ? -hex($2) : hex($2)) & 255 :
                 defined($3) ? ($3 ? -hex($4) : hex($4)) & 255 :
                 defined($5) ? ($5 ? -int($6) : int($6)) & 255 : undef;
            ($v >= 32 and $v <= 126 and $v != 0x27) ? "'" . chr($v) . "'" : $v
          } elsif (defined($7)) { $ofs += length($7) - 2; $7 }
          elsif (defined($8)) { ", " }
          else { $has_error = 1; "" }
        @ge;
        die "fatal: arg: syntax error in string literal db: $str0\n" if $has_error;
        #$str =~ s@', '@@g;  # This is incorrect, e.g. db 1, ', ', 2
        $strdata .= "db $str\n";
      }
    } elsif ($str =~ m@\s*([^\s:,]+)\s*:\s*\Z(?!\n)@) {
      push @labels, [$ofs, $1];
      #print STDERR ";;old: $1 equ strs+$ofs\n";
    } elsif ($str =~ m@\S@) {
      die "fatal: arg: unexpected string literal instruction: $str\n";
    }
  }
  # $strdata already has very strict syntax (because we have generated its
  # dbs), so we can do these regexp substitutions below safely.
  $strdata =~ s@([^:])\ndb @$1, @g;
  $strdata = "db " if !length($strdata);
  die "fatal: assert: missing db" if $strdata !~ m@\Adb@;
  die "fatal: assert: too many dbs" if $strdata =~ m@.db@s;
  $strdata =~ s@^db @db , @mg;
  $strdata =~ s@, 0(?=, )@, 0\ndb @g;  # Split lines on NUL.
  my $ss = 0;
  while (length($strdata) != $ss) {  # Join adjacent 'chars' arguments.
    $ss = length($strdata);
    $strdata =~ s@'([^']*)'(?:, '([^']*)')?@ my $x = defined($2) ? $2 : ""; "'$1$x'" @ge;
  }
  chomp($strdata);
  @$rodata_strs = split(/\n/, $strdata);
  my @sorteds;
  {
    my $i = 0;
    for my $str (@$rodata_strs) {
      my $rstr = reverse($str);
      substr($rstr, -3) = "";  # Remove "db ".
      substr($rstr, 0, 3) = "";  # Remove "0, ".
      $rstr =~ s@' ,\Z@@;
      push @sorteds, [$rstr, $i];
      ++$i;
    }
  }
  @sorteds = sort { $a->[0] cmp $b->[0] or $a->[1] <=> $b->[1] } @sorteds;
  my %mapi;
  for (my $i = 0; $i < $#sorteds; ++$i) {
    my $rstri = $sorteds[$i][0];
    my $rstri1 = $sorteds[$i + 1][0];
    if (length($rstri1) >= length($rstri) and substr($rstri1, 0, length($rstri)) eq $rstri) {
      $mapi{$sorteds[$i][1]} = $sorteds[$i + 1][1];
    }
  }
  my @ofss;
  my @oldofss;
  #%mapi = ();  # For debugging: don't merge anything.
  {
    my $i = 0;
    my $ofs = 0;
    my $oldofs = 0;
    my @sizes;
    for my $str (@$rodata_strs) {
      pos($str) = 0;
      my $size = 0;
      while ($str =~ m@\d+|'([^']*)'@g) { $size += defined($1) ? length($1) : 1 }
      push @sizes, $size;
      push @oldofss, $oldofs;
      $oldofs += $size;
      if (exists($mapi{$i})) {
        my $j = $mapi{$i};
        $j = $mapi{$j} while exists($mapi{$j});
        $mapi{$i} = $j;
        #print STDERR ";$i: ($str) -> ($rodata_strs->[$j]}\n";
        push @ofss, undef;
      } else {
        push @ofss, $ofs;
        $ofs += $size;
        #print STDERR "$str\n";
      }
      ++$i;
    }
    if (%mapi) {
      for ($i = 0; $i < @$rodata_strs; ++$i) {
        my $j = $mapi{$i};
        $ofss[$i] = $ofss[$j] + $sizes[$j] - $sizes[$i] if defined($j) and !defined($ofss[$i]);
      }
    }
    push @ofss, $ofs;
    push @oldofss, $oldofs;
  }
  {
    for my $str (@$rodata_strs) {
      die "fatal: assert: missing db-comma\n" if $str !~ s@\Adb , @db @;  # Modify in place.
      # !! if TODO(pts): length($str) > 500, then split to several `db's.
      $str .= "\n";
    }
    #print $outfh "section .rodata\n";  # Printed by the caller.
    print $outfh "__strs:\n";
    my $i = 0;
    my $pi = 0;
    for my $pair (@labels) {
      my($lofs, $label) = @$pair;
      ++$i while $i + 1 < @oldofss and $oldofss[$i + 1] <= $lofs;
      die "fatal: assert: bad oldoffs\n" if $i >= @oldofss;
      my $ofs = $lofs - $oldofss[$i] + $ofss[$i];
      for (; $pi < $i; ++$pi) {
        #print STDERR "$rodata_strs->[$pi]\n" if !exists($mapi{$pi});
        print $outfh "\t\t", $rodata_strs->[$pi] if !exists($mapi{$pi});
      }
      if ($lofs != $oldofss[$i] or exists($mapi{$i})) {
        if (exists($mapi{$i})) {
          # !! TODO(pts): Find a later (or earlier), closer label, report relative offset there.
          print $outfh "$label equ __strs+$ofs  ; old=$lofs\n";
        } else {
          my $dofs = $lofs - $oldofss[$i];
          #print STDERR "$label equ \$+$dofs\n";
          print $outfh "$label equ \$+$dofs\n";
        }
      } else {
        #print STDERR "$label:\n";
        print $outfh "$label:\n";
      }
    }
    for (; $pi < @$rodata_strs; ++$pi) {
      #print STDERR "$rodata_strs->[$pi]\n" if !exists($mapi{$pi});
      print $outfh "\t\t", $rodata_strs->[$pi] if !exists($mapi{$pi});
    }
  }
  @$rodata_strs = ();
}

# ---

sub print_commons($$$) {
  my($outfh, $common_by_label, $define_when_defined) = @_;
  return if !%$common_by_label;
  my @commons2;
  for my $label (sort(keys(%$common_by_label))) {
    die "fatal: assert: common value syntax\n" if $common_by_label->{$label} !~ m@\A(\d+):(\d+)\Z(?!\n)@;
    push @commons2, [$label, $1 + 0, $2 + 0];
  }
  # (alignment decreasing, size decreasing, name lexicographically increasing).
  @commons2 = sort { $b->[2] <=> $a->[2] or $b->[1] <=> $a->[1] or $a->[0] cmp $b->[0] } @commons2;
  print $outfh "\nsection .bss  ; common\n";
  # NASM 0.98.39 and 0.99.06 report phase errors with if the .nasm file
  # contains forward-referenced `common' directives, even without the equ
  # hack below. It works with NASM 2.13.02, but only without the `equ'
  # hack: with `equ' it's Segmentation fault when running.
  #
  # Thus we emit the .bss manually even for `nasm -f elf'. Thus, without
  # the `common', it's not possible for many .c source file to say `int
  # var;'. One of them must have `int var;', the others must have `extern
  # int var;'.
  if (0) {
    print $outfh "%ifidn __OUTPUT_FORMAT__, elf\n";
    for my $tuple (@commons2) {
      my($label, $size, $alignment) = @$tuple;
      #print $outfh "common $label $size:$alignment\n";
      #if (exists($define_when_defined{$label})) {
      #  my $label1 = $define_when_defined{$label};
      #  print $outfh "$label1 equ $label\n";
      #}
      if (exists($define_when_defined->{$label})) {
        my $label1 = $define_when_defined->{$label};
        #print $outfh "$label1 equ $label\n";
        print $outfh "common $label1 $size:$alignment\n";
      } else {
        print $outfh "common $label $size:$alignment\n";
      }
    }
    print $outfh "%else  ; ifidn __OUTPUT_FORMAT__, elf\n";
  }
  for my $tuple (@commons2) {
    my($label, $size, $alignment) = @$tuple;
    print $outfh "alignb $alignment\n" if $alignment > 1;
    print $outfh "$label: resb $size  ; align=$alignment\n";
    if (exists($define_when_defined->{$label})) {
      my $label1 = $define_when_defined->{$label};
      print $outfh "$label1 equ $label\n";
    }
  }
  if (0) {
    print $outfh "%endif ; ifidn __OUTPUT_FORMAT__, elf\n";
  }
}

sub print_nasm_header($$$$$) {
  my($outfh, $cpulevel, $data_alignment, $is_win32, $mydirp) = @_;
  #my $data_alignment = ...;  # Configurable here. =1 is 3 bytes smaller, =4 is faster. TODO(pts): Modify the owcc invocation as well.
  die "fatal: invalid characters in directory: $mydirp\n" if $mydirp =~ y@['\r\n]@@;  # Bad for %include arg.
  print $outfh qq(; .nasm source file generated by as2nasm\nbits 32\n);
  if ($is_win32) {
    print $outfh qq(
%ifidn __OUTPUT_FORMAT__, elf  ; Make it work without elf.inc.nasm.
  section .text align=1
  section .rodata align=$data_alignment
  section .data align=$data_alignment
  section .bss align=$data_alignment
  %macro _end 0
  %endm
  %macro kcall 2
  extern %1  ; Example %1: __imp__WriteFile\@20
  call [%1]
  %endm
%else
  %include '${mydirp}pe.inc.nasm'  ; To make `nasm -f bin' produce a Win32 executable program.
  %define _PE_PROG_CPU_UNCHANGED
  _pe_start 32, $data_alignment|sect_many|console
%endif
);
  } else {
    print $outfh qq(
%ifidn __OUTPUT_FORMAT__, elf  ; Make it work without elf.inc.nasm.
  section .text align=1
  section .rodata align=$data_alignment
  section .data align=$data_alignment
  section .bss align=$data_alignment
  %macro _end 0
  %endm
  %macro kcall 2  ; as2nasm doesn't generate such kcall instuctions, but some .nasm sources may have them.
  extern %1  ; Example %1: __imp__WriteFile\@20
  call [%1]
  %endm
%else
  %include '${mydirp}elf.inc.nasm'  ; To make `nasm -f bin' produce an ELF executable program.
  %define _ELF_PROG_CPU_UNCHANGED
  _elf_start 32, Linux, $data_alignment|sect_many|shentsize
%endif
);
  }
  print $outfh qq(%ifndef _PROG_MACRO_ABI_DEFINED
  %macro _abi 2
  %endm
%endif
%ifidn __OUTPUT_FORMAT__, bin
  %macro __dummy_extern 1  ; Add symbol name to NASM 0.98.39 error message.
  %endm
  %define extern __dummy_extern
%endif
);
  # After elf.inc.nasm, because it may modify the CPU level.
  my $cpulevel_str = ($cpulevel > 6 ? "" : $cpulevel >= 3 ? "${cpulevel}86" : "386");  # "prescott" would also work for $cpulevel > 6;
  print $outfh "cpu $cpulevel_str\n" if length($cpulevel_str);
  #print $outfh "\nsection .text\n";  # asm2nasm(...) will print int.
}

sub process_abitest($$$$) {
  my($outfh, $name, $insts, $lc) = @_;
  if ($name eq "retsum") {
    # To check which -mregparm=0 ... -regparm=3 was used for compilation,
    # irrespective of the GCC optimization level: If there is a `sub esp, sv'
    # instruction, remember sv. Othervise let sv be 0. Count the number of
    # [esp+...] (only displacements larger than sv) and [ebp+...] (only
    # positive displacements) effective addresses in the function code: c. Then
    # the regparm value is (3 - c).
    #
    # __attribute__((used)) static int __abitest_retsum(int a1, int a2, int a3) { return a1 + a2 + a3; }
    my $addc = 0;
    for my $inst (@$insts) {
      ++$addc if $inst =~ m@\A\t*add (?!esp,)@;
    }
    if ($addc != 2) {
      print STDERR "error: expected 2 adds in abitest $name ($lc): $name\n";
      return 1;
    }
    my $c3 = 3;
    my $sv = 0; my $ebxc = 0; my $ecxc = 0;
    for my $inst (@$insts) {
      if ($inst =~ m@\A\t*sub esp, (0+|[1-9]\d*|([^\[]]))$@) {  # TODO(pts): Hex etc.
        if (defined($2)) { $c3 = -2 }  # Immediate is not decimal.
        else { $sv += $1 }
      } elsif ($inst =~ m@\[e([sb])p[+](?!-)(?:(([0-9][0-9a-fA-F]*)[hH]|0+|[1-9]\d*)\])?@) {
        if (defined($3)) { --$c3 if hex($3) > ($1 eq "s" ? $sv : 0) }
        elsif (defined($2)) { --$c3 if $2 > ($1 eq "s" ? $sv : 0) }
        else { $c3 = -1 }  # Displacement (42) is not decimal.
      }
      ++$ecxc if $inst =~ m@, ecx\Z@;
      ++$ebxc if $inst =~ m@, ebx\Z@;
    }
    if ($c3 >= 0 and $c3 <= 2 or ($c3 == 3 and $ecxc > 0 and $ebxc == 0)) {
      print $outfh "_abi cc, rp$c3\n";  # Example meaning regparm(3) calling convention: __abitest cc, rp3
    } elsif ($c3 == 3 and $ebxc > 0 and $ecxc == 0) {
      print $outfh "_abi cc, watcall\n";  # OpenWatcom __watcall calling convention.
    } else {
      print STDERR "error: abitest $name failed c3=$c3 ecxc=$ecxc ebxc=$ebxc ($lc)\n";
      return 1;
    }
  } elsif ($name eq "divdi3") {
    # To check which regparm(...) value GCC is using for calling __divdi3,
    # distinguishing between 0 and 3, irrespective of the GCC optimization
    # level: Check the block of `push' and `mov' instructions preceding the
    # `call __divdi3' instruction. If there are 4 `push [ebp+...]' or `push
    # [esp+...]' instructions, then it's regparm(0). Otherwise, if there are 2
    # `push [ebp+...]' or `push [esp+...]' instructions and a `mov eax,
    # [...+...]' and a `mov edx, [...+...]' then it's regparm(3). Otherwise the
    # detection has failed. The actual rule implemented is a bit more complex,
    # to support different code generation.
    #
    # __extension__ __attribute__((used)) __attribute__((regparm(0))) static long long __abitest_divdi3(long long a, long long b) { return a / b; }
    my $i = @$insts;
    --$i while $i > 0 and $insts->[$i - 1] !~ m@\A\t*call __+divdi3\Z@;
    if ($i == 0) {
      print STDERR "error: missing call to __divdi3 in abitest $name ($lc)\n";
      return 1;
    }
    --$i;
    #print STDERR "divdi3_insts=(@$insts)\n";
    my $movc = 0; my $pushc = 0; my $has_lea_ecx = 0;
    for (my $j = 0; $j < $i; ++$j) {
      if ($insts->[$j] =~ m@\A\t*lea ecx, \[e[bs]p[+](?!-)@) {
        $has_lea_ecx = 1; last
      }
    }
    while ($i > 0) {
      if ($insts->[$i - 1] =~ m@\A\t*mov e[ad]x, \[e[bs]p+(?!-)@) {
        ++$movc;
        --$i;
      } elsif ($insts->[$i - 1] =~ m@\A\t*mov \[esp(?:[+](?:0|[1-9]\d*))?\],@) {
        ++$pushc;
        --$i;
      } elsif ($insts->[$i - 1] =~ m@\A\t*(?:push (?:dword )?\[e[bs]p[+](?!-)|(mov) e[ad]x,)@) {
        --$i;
        defined($1) ? ++$movc : ++$pushc;
      } elsif ($has_lea_ecx and $insts->[$i - 1] =~ m@\A\t*(?:push (?:dword )?\[ecx[+](?!-)|(mov) e[ad]x,)@) {
        --$i;
        defined($1) ? ++$movc : ++$pushc;
      } else {
        last
      }
    }
    if ($movc >= 2 and $pushc == 2) {
      print $outfh "_abi cc_divdi3, rp3\n";
    } elsif ($pushc == 4) {
      print $outfh "_abi cc_divdi3, rp0\n";
    } else {
      # TODO(pts): Only fail it if _divdi3 is used by actual code below. Othwerwise just warn.
      print STDERR "error: abitest $name failed: movc=$movc pushc=$pushc ($lc)\n";
      return 1;
    }
  } else {
    print STDERR "error: unknown abitest $name, please update libc.h ($lc): $name\n";
    return 1;
  }
  0
}

my %gp_regs = map { $_ => 1 } qw(al cl dl bl ah ch dh bh ax cx dx bx sp bp si di eax ecx edx ebx esp ebp esi edi);

# --- Convert from GNU as (AT&T) syntax to NASM.

# !! Was fuzz2.pl complete? Why not jb, jl, cmpxchg8b, fcmovl, prefetchw?
my %force_nosize_insts = map { $_ => 1 } qw(
    arpl call cmovb cmovl fldcw fnstcw fnstsw fstcw fstsw imul lmsw lsl mul
    rcl rol sbb setb setl shl smsw sub verw jb jnb jl jnl cmpxchg8b lcall fcmovb fcmovnb
    prefetchw syscall cbw iretw popaw popfw pushaw pushfw fisttpll);

my %nosize_arg_insts = map { $_ => 1 } qw(lea lds les lfs lgs lss lgdt lidt sgdt sidt);

my %prefix_insts = map { $_ => 1 } qw(cs ds es fs gs lock rep repe repne repnz repz ss wait);

my %str_arg_insts = map { $_ => 1 } qw(ins outs lods stos movs cmps scas);

# fdivp--fdivrp and fsubp--fsubrp instructions are swapped, these are opposites:
#
# * NASM 0.98.39 == NASM 2.13.02 == FASM 1.73.30 == https://www.felixcloutier.com/x86/fsub:fsubp:fisub
# * GNU as 2.30 == GNU binutils 2.30 == GCC 7.5.0 == GCC 12.2.
my %inst_map = qw(fiadds fiaddw ficoms ficomw ficomps ficompw fidivs fidivw
    fidivrs fidivrw filds fildw fimuls fimulw fists fistw fistps fistpw
    fisttps fisttpw  fisubs fisubw  fisubrs fisubrw
    cbtw cbw  cltd cdq  cwtd cwd  cwtl cwde
    fdivp fdivrp  fdivrp fdivp  fsubp fsubrp  fsubrp fsubp);

my %mov_extend_insts = map { $_ => 1 } qw(movsb movsw movzb movzw);

my %shift_insts = map { $_ => 1 } qw(rcl rcr rol ror shl sar shl shr);

my %special_arg_insts = (map { $_ => 1 } qw(bound enter lcall ljmp in out nop
    lar lsl monitor mwait movzx movsx fisttpll fisttp),
    keys(%str_arg_insts), keys(%shift_insts));

my %reg32_to_index = ('eax' => 0, 'ecx' => 1, 'edx' => 2, 'ebx' => 3, 'esp' => 4, 'ebp' => 5, 'esi' => 6, 'edi' => 7);

my %as_string_escape1 = ("b" => "\x08", "f" => "\x0c", "n" => "\x0a", "r" => "\x0d", "t" => "\x09", "v" => "\x0b");

my %divdi3_labels = map { $_ => 1 } qw(F___divdi3 F___udivdi3 F___moddi3 F___umoddi3);

sub fix_label($$$$;$) {
  my($label, $bad_labels, $used_labels, $local_labels, $skip_mark_as_used) = @_;
  if ($label =~ m@\A[.]L(\w+)\Z(?!\n)@) {  # Typically: .L1 and .LC0
    $label = "L_$1";
  } elsif ($label =~ m@\A__imp__[a-zA-Z_\@?][\w.\@?\$~#]*\Z(?!\n)@) {  # DLL import function pointer. Must always be global.
    # Keep it.
  } elsif ($label =~ m@\A([a-zA-Z_\@?][\w.\@?\$~#]*)\Z(?!\n)@) {  # Match NASM label.
    my $label2 = "S_$1";
    $label = exists($local_labels->{$label2}) ? $label2 : "F_$1";
  } else {
    push @$bad_labels, $label;
    return "?";
  }
  $used_labels->{$label} = 1 if !$skip_mark_as_used;
  $label
}

sub fix_labels($$$$) {
  my($s, $bad_labels, $used_labels, $local_labels) = @_;
  die if !defined($s);
  $s =~ s~([0-9][0-9a-zA-Z]*)|([.a-zA-Z_\@?][\w.\@?\$\~#]*)~ my $s2 = $2; my $label; defined($1) ? $1 : fix_label($2, $bad_labels, $used_labels, $local_labels) ~ge;
  $s
}

sub fix_ea($$$$$$) {
  my ($segreg, $displacement, $regs, $bad_labels, $used_labels, $local_labels) = @_;
  # We could remove whitespace from $displacement and $regs, but we don't care.
  $regs =~ y@% @@d;
  $regs =~ s@,@+@;  # Only the first ','.
  $regs =~ s@,@*@;  # Only the second ','.
  # We could do more syntax checks here.
  if ($displacement =~ m@[^ ]@) {
    $displacement = "+" . $displacement if length($regs) and $displacement !~ m@\A-(?:0[xX][0-9a-fA-F]+|0|[1-9]\d*)\Z(?!\n)@;
    $displacement = fix_labels($displacement, $bad_labels, $used_labels, $local_labels);
  }
  $segreg = (defined($segreg) and length($segreg)) ? "$segreg:" : "";
  $segreg = "" if ($segreg eq "ss:" and $regs =~ m@bp@) or ($segreg eq "ds:" and $regs !~ m@bp@);  # Remove superfluous segment prefix. GNU as does it by default, NASM 0.98.39 doesn't.
  "[$segreg$regs$displacement]"
}

sub fix_reg($) {
  my $reg = $_[0];
  return "st0" if $reg eq "st";
  $reg =~ s@\Ast\((\d+)\)\Z(?!\n)@st$1@;
  $reg
}

# Converts GNU as syntax to NASM 0.98.39 syntax, Supports only a small
# subset of GNU as syntax, mostly the one generated by GCC, but some
# hand-written .as files also work.
#
# !! Rename local labels (L_* and also non-.globl F_) by file: L1_* F2_*.
sub as2nasm($$$$$$$$$$) {
  my($srcfh, $outfh, $first_line, $lc, $rodata_strs, $is_win32, $undefineds, $define_when_defined, $common_by_label, $is_start_found_ref) = @_;
  my %unknown_directives;
  my $errc = 0;
  my $is_comment = 0;
  my $do_omit_call_to___main = 0;
  my $section = ".text";
  my @abitest_insts;  # Label and list of instructions being buffered.
  my $used_labels = {};
  my %defined_labels;
  my %externs;
  my %local_labels;
  my %global_labels;
  print $outfh "\nsection $section\n";
  while (defined($first_line) or defined($first_line = <$srcfh>)) {
    ++$lc;
    ($_, $first_line) = ($first_line, undef);
    if ($is_comment) {
      next if !s@\A.*[*]/@@s;  # End of multiline comment.
      $is_comment = 0;
    }
    y@[\r\n]@@;
    if (m@/[*]@) {
      if (m@"@) {
        s@/[*].*?[*]/|("(?:[^\\"]+|\\.)*")@ defined($1) ? $1 : " " @sge;
        s@/[*].*|("(?:[^\\"]+|\\.)*")@ $is_comment = 1 if !defined($1); defined($1) ? $1 : "" @sge;
      } else {  # Easier.
        s@/[*].*?[*]/@ @sg;
        $is_comment = 1 if s@/[*].*@@s;  # Start of multiline comment.
      }
    }
    s@\A[\s;]+@@;
    s@[\s;]+\Z(?!\n)@@;
    if (!m@"@) {
      s@\s+@ @g;
    } else {
      s@\s+|("(?:[^\\"]+|\\.)*")@ defined($1) ? $1 : " " @ge;  # Keep quoted spaces intact.
    }
    if (m@;@) {
      if (m@\A[.]def ([^\s:,;]+) *; *[.]scl (?:(\d+)[; ])?@) {
        # Example from MinGW: .def	_mainCRTStartup;	.scl	2;	.type	32;	.endef
        if (defined($2) and $2 eq "2") {
          $_ = "";  # Global or extern symbol $1, keep it.
          $do_omit_call_to___main = 1 if $1 eq "___main";  # MinGW GCC 4.8.2.
        } else {
          $_ = ".type $1," if !defined($2) or $2 ne "2";  # Will make it implicitly local below.
        }
      } else {
        my $has_err = 0;
        if (m@"@) {
          s@;.*|("(?:[^\\"]+|\\.)*")@ $has_err = 1 if !defined($1); defined($1) ? $1 : "" @sge;
        } else {
          s@;.*@@s;
          $has_err = 1;
        }
        if ($has_err) {
          ++$errc;
          # TODO(pts): Support multiple instructions per line.
          print STDERR "error: multiple instructions per line, all but the first ignored ($lc): $_\n";
        }
      }
    }
    next if !length($_);
    my @bad_labels;
    if (s@\A([^\s:,]+): *@@) {
      if (!length($section)) {
        ++$errc;
        print STDERR "error: label outside section ($lc): $_\n";
      }
      my $label = $1;
      # GCC 7.5.0 without `-fno-unwind-tables -fno-asynchronous-unwind-tables' emits .LFB0: ... .LFE0: for functions. We don't need these labels.
      next if $label =~ m@\A[.]LF[BE]@;
      $label = fix_label($label, \@bad_labels, $used_labels, \%local_labels);
      if (length($section) == 1) {
        if ($label =~ m@\A(?:L_C|F_LC)@) {  # Label for string literal, e.g. .LC0 (GCC 7.5 on Linux) or LC0 (MinGW GCC 4.8.2).
          push @$rodata_strs, "$label:";
        } else {
          $section = ".rodata";
          print $outfh "$label:\n";
        }
      } elsif ($label =~ m@\A[SF]___+abitest_(.*)\Z@ and $section eq ".text") {  # Emitted by libc.h. Typically it's S_ because of static.
        @abitest_insts = ($1);
        $defined_labels{$label} = 1;
      } else {
        print $outfh "$label:\n";
        if ($label eq "F__start" or $label eq "F__mainCRTStartup") {  # !! TODO(pts): Indicate the entry point smarter.
          print $outfh "_start:\n";
          $$is_start_found_ref = 1;
        }
      }
      $defined_labels{$label} = 1;
      if (exists($define_when_defined->{$label})) {
        my $label1 = $define_when_defined->{$label};
        print $outfh "$label1 equ $label\n";
        $defined_labels{$label1} = 1;
      }
    }
    if (m@\A[.]@) {
      if (@abitest_insts) {
        if (!m@[.]cfi_@) {
          ++$errc;
          print STDERR "error: incomplete abitest ($lc): $_\n";
          @abitest_insts = ();
        }
      }
      if (m@\A[.](?:file "|size |loc |cfi_|ident ")@) {
        # Ignore this directive (.file, .size, .type).
      } elsif (m@\A([.](?:text|data|rodata))\Z@) {
        $section = $1;
        print $outfh "section $section\n";
      } elsif (m@\A[.]type ([^\s:,]+),.*\Z@) {  # Example: .type main, @function
        # If there is a .def or .type before a .globl for that label, then
        # declare it as local.
        my $label = fix_label($1, \@bad_labels, $used_labels, \%local_labels, 1);
        if (exists($defined_labels{$label})) {
          ++$errc;
          print STDERR "error: label defined before implicit local ($lc): $label\n";
        }
        if ($label =~ m@\AL_@) {
          ++$errc;
          print STDERR "error: local-prefix label cannot be declared implicit local ($lc): $label\n";
        } elsif ($label =~ m@\A__imp__@) {
          ++$errc;
          print STDERR "error: __imp__-prefix label cannot be declared implicit local ($lc): $label\n";
        } elsif (exists($global_labels{$label}) or exists($externs{$label})) {  # Must start with F_ or __imp__.
          # No-op.
        } elsif ($label =~ m@\AF_@ and exists($used_labels->{$label})) {
          my $label2 = $label;
          die if $label2 !~ s@\AF_@S_@;
          $define_when_defined->{$label2} = $label;
          if (exists($defined_labels{$label2})) {
            print $outfh "$label equ $label2\n";
            $defined_labels{$label} = 1;
          } else {
            # TODO(pts): Do an initial scanning pass to avoid this workaround. The workaround won't work for multiple input files with conflicting local labels.
            $define_when_defined->{$label2} = $label;
          }
          $local_labels{$label2} = 1;
          $used_labels->{$label2} = 1;
        } else {
          die "fatal: assert: bad implicit local label: $label\n" if $label !~ s@\A[FS]_@S_@;
          $local_labels{$label} = 1;
        }
      } elsif (m@\A[.]globl ([^\s:,]+)\Z@) {
        # GCC 7.5.0 emits `.globl __udivdi3', but no `.globl' for other
        # extern functions. So in the NASM output we end up with both
        # `global __udivdi3' and `extern __udivdi3'. That's fine, even for
        # `nasm -f elf'.
        my $label = fix_label($1, \@bad_labels, $used_labels, \%local_labels, 1);
        print $outfh "global $label\n" if !exists($divdi3_labels{$label});
        print $outfh "global _start\n" if $label eq "F__start" or $label eq "F__mainCRTStartup";  # !! TODO(pts): Indicate the entry point smarter.
        if (exists($defined_labels{$label})) {
          ++$errc;
          print STDERR "error: label defined before .global ($lc): $label\n";
        }
        if ($label =~ m@\AL_@) {
          ++$errc;
          print STDERR "error: local-prefix label cannot be declared .global ($lc): $label\n";
        } elsif ($label =~ m@\AS_@) {
          ++$errc;
          print STDERR "error: label already .local before .global ($lc): $label\n";
        } else {
          $global_labels{$label} = 1;
        }
      } elsif (m@\A[.]local ([^\s:,]+)\Z@) {
        my $label = fix_label($1, \@bad_labels, $used_labels, \%local_labels, 1);
        if (exists($defined_labels{$label})) {
          ++$errc;
          print STDERR "error: label defined before .local ($lc): $label\n";
        }
        if ($label =~ m@\AL_@) {
          ++$errc;
          print STDERR "error: local-prefix label cannot be declared .local ($lc): $label\n";
        } elsif ($label =~ m@\A__imp__@) {
          ++$errc;
          print STDERR "error: __imp__-prefix label cannot be declared .local ($lc): $label\n";
        } elsif (exists($global_labels{$label})) {  # Must start with F_ or __imp__.
          ++$errc;
          print STDERR "error: label already .global before .local ($lc): $label\n";
        } elsif (exists($externs{$label})) {
          ++$errc;
          print STDERR "error: label already .extern before .local ($lc): $label\n";
        } elsif ($label =~ m@\AF_@ and exists($used_labels->{$label})) {
          #++$errc;
          #print STDERR "error: label already used as non-.local before .local ($lc): $label\n";
          my $label2 = $label;
          die if $label2 !~ s@\AF_@S_@;
          $define_when_defined->{$label2} = $label;
          if (exists($defined_labels{$label2})) {
            print $outfh "$label equ $label2\n";
            $defined_labels{$label} = 1;
          } else {
            # TODO(pts): Do an initial scanning pass to avoid this workaround. The workaround won't work for multiple input files with conflicting local labels.
            $define_when_defined->{$label2} = $label;
          }
          $local_labels{$label2} = 1;
          $used_labels->{$label2} = 1;
        } else {
          die "fatal: assert: bad .local label: $label\n" if $label !~ s@\A[FS]_@S_@;
          $local_labels{$label} = 1;
        }
        print $outfh ";local $label\n";  # NASM doesn't need it.
      } elsif (m@\A[.]section [.]text[.](?:unlikely|startup) *(?:,|\Z)@) {
        # GCC puts main to .text.startup.
        # !! What is .text.unlikely?
        $section = ".text";  # !! Any better?
        print $outfh "section $section\n";
      } elsif (m@\A[.]section [.]ro?data(?:[.]str[.a-z0-9]*)?(?:\Z|\s*,)@) {
        # Example $_ for MinGW: .section .rdata,"dr"
        # Example $_: .section .rodata.str1.1,...
        if ($rodata_strs) {
          $section = "S";
          print $outfh "section .rodata\n";
        } else {
          $section = ".rodata";
          print $outfh "section $section\n";
        }
      } elsif (m@\A[.]section [.]note[.]GNU-stack[,]@) {
        # Non-executable stack marker: .section .note.GNU-stack,"",@progbits
        # !! respect it.
        $section = "";
      } elsif (m@\A[.]extern ([^\s:,]+)\Z@) {  # GCC doesn't write these.
        my $label = fix_label($1, \@bad_labels, $used_labels, \%local_labels, 1);
        if ($label =~ m@\AL_@) {
          ++$errc;
          print STDERR "error: local-prefix label cannot be declared .extern ($lc): $label\n";
        } elsif ($label =~ m@\AS_@) {
          ++$errc;
          print STDERR "error: label already .local before .extern ($lc): $label\n";
        } else {
          die "fatal: assert: bad .extern label: $label\n" if $label !~ m@\AF_@;
          $externs{$label} = 1;
        }
      } elsif (m@\A[.]comm ([^\s:,]+), *(0|[1-9]\d*), *(0|[1-9]\d*)\Z@) {
        if (!length($section)) {
          ++$errc;
          print STDERR "error: .comm outside section ($lc): $_\n";
        } else {
          # !! TODO(pts): Do a proper rearrangement of .comm within .bss based on alignment.
          my ($size, $alignment) = ($2 + 0, $3 + 0);
          if ($alignment & ($alignment - 1)) {
            ++$errc;
            print STDERR "error: alignment value not a power of 2 ($lc): $_\n";
            $alignment = 1;
          } elsif ($alignment < 2) {
            $alignment = 1;
          } elsif ($alignment > 4) {
            # See the comments at .align why.
            print STDERR "warning: alignment value larger than 4 capped to 4 ($lc): $_\n" if $alignment > 4;
            $alignment = 4;
          }
          my $label = fix_label($1, \@bad_labels, $used_labels, \%local_labels, 1);
          $defined_labels{$label} = 1;
          my $value = "$size:$alignment";
          if (!exists($common_by_label->{$label})) {
            $common_by_label->{$label} = $value;
          } elsif ($common_by_label->{$label} ne $value) {
            ++$errc;
            print STDERR "error: common mismatch for $label, latter ignored: $common_by_label->{$label} vs $value\n";
          }
        }
      } elsif (m@\A[.]align (0|[1-9]\d*)\Z@) {
        if (!length($section)) {
          ++$errc;
          print STDERR "error: .align outside section ($lc): $_\n";
        } elsif ($section eq ".bss") {
          # We'd need `alignb'. Does it make sense? We don't even support .bss directly.
          print STDERR "error: .align in .bss ignored ($lc): $_\n" if !exists($unknown_directives{".align/bss"});
          $unknown_directives{".align/bss"} = 1;
        } else {
          $section = ".rodata" if length($section) == 1;  # Not a string literal.
          my $alignment = $1 + 0;
          if ($alignment & ($alignment - 1)) {
            ++$errc;
            print STDERR "error: alignment value not a power of 2 ($lc): $_\n";
          } elsif ($alignment > 1) {
            # For some global variables (especially char arrays), GCC
            # generates `.align 32'. It doesn't make sense, the user should
            # add __attribute__((aligned(4))) to the declaration.
            print STDERR "warning: alignment value larger than 4 capped to 4 ($lc): $_\n" if $alignment > 4;
            # Also we'd need to increase $data_alignment for elf.inc.nasm
            # for $alignment > 4 to make any sense, and it's too late for
            # that.
            #
            # !! TODO(pts): Do an initial scan for .align and .comm, and
            # then set $data_alignment to 4, 8, 16 or 32. elf.inc.nasm
            # supports up to 32 for ELF-32.
            $alignment = 4 if $alignment > 4;
            my $inst = ($section eq ".text") ? "nop" : "db 0";
            print $outfh "align $alignment, $inst\n";
            #print STDERR "warning: align ignored ($lc): $_\n" if !exists($unknown_directives{".align"});  # !!
            #$unknown_directives{".align"} = 1;
          }
        }
      } elsif (m@\A[.](byte|value|long) (\S.*)\Z@) {  # !! 64-bit data? floating-point data?
        my $inst1 = $1;
        my $expr = fix_labels($2, \@bad_labels, $used_labels, \%local_labels);
        if (length($section) > 1) {
        } elsif (length($section) != 0) {  # "S", @$rodata_strs.
          # It doesn't look like a string. Pop and print preceding labels as well.
          # TODO(pts): Don't pop end-line labels (ending the previous string in hand-written assembly).
          my $i = @$rodata_strs;
          --$i while $i > 0 and substr($rodata_strs->[$i - 1], -1) eq ":";
          for (my $j = $i; $j < @$rodata_strs; ++$j) {
            print $outfh "$rodata_strs->[$j]\n";
          }
          splice @$rodata_strs, $i;
        } else {
          ++$errc;
          print STDERR "error: .$inst1 outside section ($lc): $_\n";
        }
        my $inst = $inst1 eq "byte" ? "db" : $inst1 eq "value" ? "dw" : $inst1 eq "long" ? "dd" : "d?";
        print $outfh "\t\t$inst $expr\n";
      } elsif (m@\A[.]((string)|ascii)(?=\Z|\s)(?:\s+"((?:[^\\"]+|\\.)*)"\s*\Z)?@s) {
        if (!defined($3)) {
          ++$errc;
          print STDERR "error: bad $1 argument ($lc): $_\n";
        } else {
          my($inst1, $inst2, $data) = ($1, $2, $3);
          if (!length($section)) {
            ++$errc;
            print STDERR "error: .$inst1 outside section ($lc): $_\n";
          }
          # GNU as 2.30 does the escaping like this.
          $data =~ s@\\(?:([0-3][0-7]{2}|[0-7][0-7]?)|[xX]([0-9a-fA-F]{1,})|([bfnrtv])|(.))@
              defined($1) ? chr(oct($1) & 255) :
              defined($2) ? chr(hex(substr($2, -2)) & 255) :
              defined($3) ? $as_string_escape1{$3} :
              $4 @ges;
          $data .= "\0" if defined($inst2);
          if (length($data)) {
            $data =~ s@([\x00-\x1f\\'\x7f-\xff])@ sprintf("', %d, '", ord($1)) @ges;
            $data = "'$data'";
            $data =~ s@, ''(?=, )@@g;  # Optimization.
            $data =~ s@\A'', @@;  # Optimization.
            $data =~ s@, ''\Z@@;  # Optimization.
            if (length($section) == 1) {
              push @$rodata_strs, "db $data";
            } else {
              print $outfh "\t\tdb $data\n";
            }
          }
        }
      } else {
        die "assert: missing directive: $_\n" if !m@\A([.][^ ]+)@;
        my $d = $1;
        ++$errc;
        if (!exists($unknown_directives{$d})) {
          print STDERR "error: unknown directive $d ignored ($lc): $_\n";
          $unknown_directives{$d} = 1;
        }
      }
    } elsif (s@\A([a-z][a-z0-9]*)(?: +|\Z)@@) {
      if (length($section) <= 1) {
        ++$errc;
        print STDERR "error: instruction outside section ($lc): $_\n";
      }
      my $inst = $1;
      $inst = "wait" if $inst eq "fwait";
      while (exists($prefix_insts{$inst})) {
        my $suffix = ($inst eq "wait" or !length($_)) ? "\n" : " ";
        print $outfh $inst, $suffix;
        $inst = s@\A([a-z][a-z0-9]*) *@@ ? $1 : "";
        $inst = "wait" if $inst eq "fwait";
      }
      if (!length($inst)) {
        goto check_labels if !length($_);
        $inst = "?";
        ++$errc;
        print STDERR "error: no instruction after prefix ($lc): $_\n";
      }
      #print STDERR "INSA $inst $_\n";
      $inst = $inst_map{$inst} if exists($inst_map{$inst});
      my $arg1_prefix;
      my $instwd = "";
      if (!exists($force_nosize_insts{$inst}) and $inst =~ s@([bwl])\Z@@) {
        if (exists($nosize_arg_insts{$inst})) {
        } elsif (exists($str_arg_insts{$inst})) {
          my $suffix = ($1 eq "l") ? "d" : $1;
          $inst .= $suffix;
          $_ = "";  # Remove arguments without checking them.
        } elsif (exists($mov_extend_insts{$inst})) {
          my $suffix = $1 eq "b" ? " byte" : $1 eq "w" ? " word"  : $1 eq "l" ? " dword" : "";
          die "fatal: assert: mov_extend: $inst\n" if $inst !~ s@([bw])\Z@x@;
          $arg1_prefix = $1 eq "b" ? "byte " : $1 eq "w" ? "word " : "";
          $instwd = $suffix;
        } elsif (!length($_)) {  # E.g. "cbtw" to "cbt".
        } elsif ($1 eq "b") {
          $instwd = " byte"
        } elsif ($1 eq "w") {
          $instwd = " word"
        } elsif ($1 eq "l") {
          $instwd = " dword"
        }
      }
      my $is_args_special = exists($special_arg_insts{$inst});
      substr($inst, 0, 1) = "" if ($inst eq "lcall" or $inst eq "ljmp");
      if  ($inst =~ m@\A(?:call\Z|j[a-z]{1,3}|loop)@) {  # Includes jmp.
        if (s@\A[*]@@) {
           if ($is_win32 and $inst eq "call" and m@\A__imp__([^\s:\[\],+\-*/()<>`]+?)((?:\@\d+)?)\Z@) {
             print $outfh "\t\tkcall __imp__$1$2, '$1'\n";  # Example: kcall __imp__GetStdHandle@4, 'GetStdHandle'
             next;
           }
        } elsif ($do_omit_call_to___main and $inst eq "call" and $_ eq "___main") {
          next;  # Just omit it, argc and argv re already fine.
        } elsif (@abitest_insts and $inst eq "call") {
          push @abitest_insts, "\t\tcall $_\n";
          next;  # Don't do $used_labels{$label} = 1.
        } elsif (!m@\A[\$]@) { s@\A@\$@ }  # Relative immediate syntax for `jmp short' or `jmp near'.
      }
      pos($_) = 0;
      my @args;
      my $tmp_arg;
      while (pos($_) < length($_)) {
        if (m@\G%(\w+|st\(\d+\))(?:, *|\Z)@gc) { push @args, ((substr($1, 0, 2) eq "st") ? fix_reg($1) : $1) }  # Register.
        elsif (m@\G\$([^(),]+)(?:, *|\Z)@gc) { push @args, fix_labels($1, \@bad_labels, $used_labels, \%local_labels) }  # Immediate.
        elsif (m@\G(?:%([a-z]s) *: *)?(?:([^%(),]+)|([^%(),]*)\(([^()]+)\))(?:, *|\Z)@gc) { push @args, fix_ea($1, defined($2) ? $2 : $3, defined($2) ? "" : $4, \@bad_labels, $used_labels, \%local_labels) }  # Effective address.
        elsif (m@\G([^,]*)(?:, *|\Z)@gc) {
          ++$errc;
          print STDERR "error: bad instruction argument ($lc): $1\n";
          push @args, "?";
        } else {
          my $rest = substr($_, pos($_));
          die "fatal: assert: bad instruction argument ($lc): $rest\n";
        }
      }
      @args = reverse(@args);
      if (!(@args and $is_args_special)) {  # This is the hot path, most instructions don't need special processing.
      } elsif (defined($arg1_prefix)) {  # $inst in ("movzx", "movsx").
        $args[1] = $arg1_prefix . $args[1] if @args == 2 and !exists($gp_regs{$args[1]});
      } elsif (($inst eq "call" or $inst eq "jmp") and @args == 2) {  # "lcall" and "ljmp".
        @args = "$args[1]:$args[0]";
      } elsif ($inst eq "in" or $inst eq "out") {
        @args = map { $_ eq "[dx]" ? "dx" : $_ } @args;
      } elsif ($inst eq "nop" and @args) {
        my $a0 = $args[0];
        if (@args == 1 and exists($reg32_to_index{$args[0]})) {
          print $outfh sprintf("db 0x0f, 0x1f, 0x%02x  ; nop %s\n", 0xc0 | $reg32_to_index{$args[0]}, $args[0]);
          goto check_labels
        } elsif (@args == 1 and exists($reg32_to_index{"e$args[0]"})) {
          print $outfh sprintf("db 0x66, 0x0f, 0x1f, 0x%02x  ; nop %s\n", 0xc0 | $reg32_to_index{"e$args[0]"}, $args[0]);
          goto check_labels
        } else {
          $inst .= "?";
          @args = reverse(@args);
          ++$errc;
          print STDERR "error: nop argument too complex for NASM 0.98.39 ($lc): $inst $_\n";
        }
      } elsif (exists($str_arg_insts{$inst})) {
        my $suffix = ((grep { $_ eq "al" } @args) ? "b" : "") . ((grep { $_ eq "ax" } @args) ? "w" : "") . ((grep { $_ eq "eax" } @args) ? "d" : "");
        if (length($suffix) != 1) {
          ++$errc;
          print STDERR "error: unrecognized string instruction size $suffix ($lc): $inst $_\n";
          $suffix = "?";
        }
        $inst .= $suffix;
        @args = ();
      } elsif (exists($shift_insts{$inst})) {
        push @args, "1" if @args == 1;
      } elsif ($inst eq "bound" or $inst eq "enter") {
        @args = reverse(@args);
      } elsif ($inst eq "lar" or $inst eq "lsl") {
        substr($args[1], 0, 0) = "e" if exists($reg32_to_index{"e$args[1]"});  # NASM 0.98.39 accepts only 32-bit register. So upgrade it from 16 bits.
      } elsif ($inst eq "fisttpll" or $inst eq "fisttp") {
        ($inst, $instwd) = ("fisttp", " qword") if $inst eq "fisttpll";
        if (@args == 1 and $args[0] eq "[ebx]") {  # Just a quick hack for testing. Proper 32-bit effective address encoding would be needed, also for `nop'.
          print $outfh sprintf("db 0x%02x, 0x0b  ; $inst$instwd $args[0]\n", $instwd eq " word" ? 0xdf : $instwd eq " dword" ? 0xdb : 0xdd);
          goto check_labels
        }
        # NASM 0.98.39 generates the machine bytes of the wrokg size (qword,
        # dword and word mixed). This one has been fixed in NASM 2.13.02 (or
        # earlier).
        ++$errc;
        print STDERR "error: fisttpll args too complex for buggy NASM 0.98.39 ($lc): $inst $_\n";
      } elsif ($inst eq "monitor") {
        @args = () if @args == 3 and "@args" eq "edx ecx eax";
      } elsif ($inst eq "mwait") {
        @args = () if @args == 2 and "@args" eq "ecx eax";
      }
      my $args = @args ? " " . join(", ", @args) : "";
      # Remove unnecessary size specifier if there is a general-purpose
      # register argument, e.g. convert `mov word ax, 1' to `mov ax, 1'.
      $instwd = "" if @args and length($instwd) and @args <= 2 and (
          exists($gp_regs{$args[0]}) or (@args == 2 and !defined($arg1_prefix) and exists($gp_regs{$args[1]})));
      $_ = "\t\t$inst$instwd$args\n";
      if (@abitest_insts) {
        if ($inst eq "ret") {
          my $abitest_name = shift(@abitest_insts);
          $errc += process_abitest($outfh, $abitest_name, \@abitest_insts, $lc);
          @abitest_insts = ();
        } else {
          push @abitest_insts, $_;
        }
      } else {
        print $outfh $_;
      }
    } elsif (!length($_)) {
    } elsif ($_ eq "#APP" or $_ eq "#NO_APP") {  # Ignore, preprocessor enable/disabled.
      # https://stackoverflow.com/a/73317832
    } else {
      ++$errc;
      print STDERR "error: instruction or directive expected ($lc): $_\n";
    }
   check_labels:
    for my $label (@bad_labels) {
      ++$errc;
      print STDERR "error: bad label syntax ($lc): $label\n";
    }
  }
  if (@abitest_insts) {
    ++$errc;
    print STDERR "error: incomplete abitest ($lc): $_\n";
  }
  if (0 and $rodata_strs and @$rodata_strs) {  # For debugging: don't merge (optimize) anything.
    $section = ".rodata";
    print $outfh "\nsection $section\n";
    for my $str (@$rodata_strs) {
      $str .= "\n";
      print $outfh $str;
    }
    @$rodata_strs = ();
  }
  for my $label (sort(keys(%$common_by_label))) {
    my $label1 = $define_when_defined->{$label};
    $defined_labels{$label1} = 1 if defined($label1);
  }
  for my $label (keys(%$used_labels)) {
    $undefineds->{$label} = 1 if !exists($defined_labels{$label});
  }
  for my $label (keys(%externs)) {
    $undefineds->{$label} = 1 if !exists($defined_labels{$label});
  }
  $errc
}

# --- Conversion from WASM syntax to NASM.

# Converts WASM (OpenWatcom assembler) syntax to NASM 0.98.39 syntax,
# Supports only a very small subset of WASM syntax, mostly the one generated
# by `wdis' (the OpenWatcom disassembler), and most hand-written .wasm
# source files won't work.
#
# The input file come from `wdis -a' or `wdis -a -fi'.
sub wasm2nasm($$$$$$$) {
  my($srcfh, $outfh, $first_line, $lc, $rodata_strs, $is_win32, $is_start_found_ref) = @_;
  my $section = ".text";
  my $segment = "";
  my $bss_org = 0;
  my $is_end = 0;
  my %segment_to_section = qw(_TEXT .text  CONST .rodata  CONST2 .rodata  _DATA .data  _BSS .bss);
  my %directive_to_segment = qw(.code _TEXT  .const CONST2  .data _DATA  .data? _BSS);  # TODO(pts): Is there a way for CONST2?
  my $end_expr;
  my @abitest_insts;  # Label and list of instructions being buffered.
  my $do_hide_abitest = 0;
  while (defined($first_line) or defined($first_line = <$srcfh>)) {
    ++$lc;
    ($_, $first_line) = ($first_line, undef);
    y@\r\n@@d;
    die "fatal: line after end ($lc): $_\n" if $is_end;
    my $is_instr = s@^\t(?!\t)@@;  # Assembly instruction.
    s@\A\s+@@;
    if (s@^\s*db\s+@db @i) {
      die "fatal: comment in db line\n" if m@;@;  # TODO(pts): Parse db '?'.
      s@\s+\Z(?!\n)@@;
    } else {
      s@;.*@@s;
      s@\s+@ @g;
      s@ \Z(?!\n)@@;
      s@\s*,\s*@, @g;
    }
    if ($is_instr) {
      die "fatal: unsupported instruction in non-.text ($lc): $_\n" if $section ne ".text";
      die "fatal: unsupported quote in instruction ($lc): $_\n" if m@'@;  # Whitespace is already gone.
      if (s~^(jmp|call) near ptr (?:FLAT:)?~$1 \$~) {
      } elsif (s@^(j[a-z]+|loop[a-z]*) ([^\[\],\s]+)$@$1 \$$2@) {   # Add $ in front of jump target label.
        s@\$`([^\s:\[\],+\-*/()<>`]+)`@\$$1@g;  # Remove backtick quotes. Usually they are not present here.
      } elsif ($is_win32 and m@^call dword ptr *(?:FLAT:)?`?__imp__([^\s:\[\],+\-*/()<>`]+?)((?:\@\d+)?)`?$@) {
        $_ = "kcall __imp__$1$2, '$1'";  # Example: kcall __imp__GetStdHandle@4, 'GetStdHandle'
      } else {
        s`([\s,])(byte|word|dword) ptr (?:([^\[\],\s]*)\[(.*?)\]|FLAT:([^,]+))`
            if (defined($3)) {
              my $p = "$1$2 [$4"; my $displacement = $3;
              if (length($displacement)) {
                $p .= "+" if $displacement !~ m@\A-(?:0[xX][0-9a-fA-F]+|[0-9][0-9a-fA-F]*[hH]|0|[1-9]\d*)\Z(?!\n)@;
                $p .= $displacement;
              }
              $p .= "]"
            } else { "$1$2 [\$$5]" } `ge;
        s@^(call|jmp) dword \[@$1 [@;
        s@([\s,])([^\[\],\s]+)\[(.*?)\]@${1}[$3+$2]@g;  # `cmp al, 42[esi]'   -->  `cmp al, [esi+42]'.
        s@([-+])FLAT:([^,]+)@$1\$$2@g;
        s@([\s:\[\],+\-*/()<>])offset (?:FLAT:)?([^\s,+\-\[\]*/()<>]+)@$1\$$2@g;
        s@\$`([^\s:\[\],+\-*/()<>`]+)`@\$$1@g;  # Remove backtick quotes in `call dword [$`__imp__GetStdHandle@4`]`.
        if (m@^([a-z0-9]+) (?:byte|word|dword) ([^,]+)(, *(?:byte |word |dword )?([^,]+))?$@) {
          if (exists($gp_regs{$2}) or (defined($4) and $1 ne "movsx" and $1 ne "movzx" and exists($gp_regs{$4}))) {
            my $m3 = defined($3) ? $3 : "";
            $_ = "$1 $2$m3";  # Omit the byte|word|dword qualifier.
          }
        } elsif (m@^([a-z0-9]+) ([^,]+), *(?:byte|word|dword) ([^,]+)?$@) {
          if (exists($gp_regs{$3}) or ($1 ne "movsx" and $1 ne "movzx" and exists($gp_regs{$2}))) {
            $_ = "$1 $2, $3";  # Omit the byte|word|dword qualifier.
          }
        }
      }
      if ($rodata_strs and $segment eq "CONST") {  # C string literals.
        push @$rodata_strs, $_;
      } else {
        print $outfh "\t\t$_\n" if !$do_hide_abitest;
        if (@abitest_insts) {
          if ($_ eq "ret") {
            my $abitest_name = shift(@abitest_insts);
            # The emitted `_abi cc, watcall' or `_abi cc, rp0' may not be
            # the before all labels and code, becase the OpenWatcom C
            # compiler sometimes merges function body tails, and it may get
            # merged to a later one.
            exit(1) if process_abitest($outfh, $abitest_name, \@abitest_insts, $lc);
            @abitest_insts = ();
            $do_hide_abitest = 0;
          } else {
            push @abitest_insts, "\t\t$_\n";
          }
        }
      }
    } elsif (m@^[.]@) {
      die "fatal: incomplete abitest ($lc): $_\n" if @abitest_insts;
      if ($_ eq ".387" or $_ eq ".model flat") {  # Ignore.
      } elsif (m@^[.]386@) {
        print $outfh "cpu 386\n";
      } elsif (exists($directive_to_segment{$_})) {
        $segment = $directive_to_segment{$_};
        $section = $segment_to_section{$segment};
        print $outfh "\nsection $section  ; $segment\n";
      } else {
        die "fatal: unsupported WASM directive: $_\n" ;
      }
    } elsif (m@^[^\s:\[\],+\-*/`]+:$@) {  # Label.  TODO(pts): Convert all labels, e.g. eax to $eax.
      if ($rodata_strs and $segment eq "CONST") {
        push @$rodata_strs, "\$$_";
      } elsif (m@^__abitest_(.*?)_?:$@) {
        die "fatal: overlapping abitest ($lc): $_\n" if @abitest_insts;
        @abitest_insts = ($1);
        $do_hide_abitest = 1;
      } else {
        if ($do_hide_abitest) {  # It overlaps with code of another function.
          for (my $i = 1; $i < @abitest_insts; ++$i) {
            print $outfh "$abitest_insts[$i]\n";
          }
          $do_hide_abitest = 0;
        }
        if ($_ eq "_start_:" or $_ eq "_mainCRTStartup:") {  # Add extra start label for entry point.
          print $outfh "_start:\n";
          $$is_start_found_ref = 1;
        } elsif ($_ eq "_start:") {
          $$is_start_found_ref = 1;
        }
        print $outfh "\$$_\n";
      }
    } elsif (@abitest_insts) {
      die "fatal: incomplete abitest ($lc): $_\n" if @abitest_insts;
    } elsif (s@^(d[bwd])(?= )@@i) {
      my $cmd = lc($1);
      s@\boffset (?:FLAT:)?@\$@g if !m@'@;
      if ($rodata_strs and $segment eq "CONST") {  # C string literals.
        push @$rodata_strs, $cmd . $_;
      } else {
        print $outfh "$cmd$_\n";
      }
    } elsif (m@^(_TEXT|CONST2?|_DATA|_BSS) SEGMENT @) {
      $segment = $1;
      $section = $segment_to_section{$segment};
      print $outfh "\nsection $section  ; $segment\n";
      die "fatal: non-32-bit segment found: $_\n" if !m@ USE32 @;
    } elsif (m@^(\S+) ENDS$@) {
      die "fatal: unexpected segment end: $1\n" if $1 ne $segment;
    } elsif (m@^ORG @) {
      die "fatal: bad org instruction ($lc): $_\n" if
          !m@^ORG (?:([0-9])|([0-9][0-9a-fA-F]*)[hH])$@ or $section ne ".bss";
      my $delta_bss_org = (defined($1) ? ($1 + 0) : hex($2)) - $bss_org;
      die "fatal: .bss org decreasing ($lc): $_\n" if $delta_bss_org < 0;
      if ($delta_bss_org != 0) {
        print $outfh "resb $delta_bss_org\n";
      }
      $bss_org += $delta_bss_org;
    } elsif (m@^([^\s:\[\],+\-*/()<>`]+) LABEL BYTE$@ and $section eq ".bss") {
      print $outfh "\$$1:\n";
    } elsif (m@^end(?: ([^\s:\[\],+\-*/()<>`]+))?$@i) {
      $end_expr = $1;
      $is_end = 1;
    } elsif (m@^public ([^\s:\[\],+\-*/()<>`]+)$@i) {
      print $outfh "global \$$1\n";
    } elsif (m@^extrn (?:`([^\s:\[\],+\-*/()<>`]+)`|([^\s:\[\],+\-*/()<>`]+))(?::byte)?$@i) {
      # Example with backtick: EXTRN `__imp__GetStdHandle@4`:BYTE
      my $label = defined($1) ? $1 : $2;
      print $outfh "extern \$$label\n" if !$is_win32 or $label !~ m@\A__imp__@;
    } elsif (!length($_) or m@^DGROUP GROUP@ or m@^ASSUME @) {  # Ignore.
    } else {
      die "fatal: unsupported WASM instruction ($lc): $_\n" ;
    }
  }
  die "fatal: incomplete abitest ($lc): $_\n" if @abitest_insts;
  if (defined $end_expr) {
    print $outfh "\$_start equ $end_expr\n" if $end_expr ne "_start";
  }
}

# ---

sub detect_source_format($$$) {
  my($srcfh, $last_line_ref, $lc_ref) = @_;
  my $hdr = "";
  $$lc_ref = 0;
  while (length($hdr) < 4 and $hdr !~ m@\n@) {
    return undef if (read($srcfh, $hdr, 1, length($hdr)) or 0) != 1;
  }
  if ($hdr =~ m@\A\x7fELF@) {
    return "elf";  # Can be program (executable), object (relocatable) etc.
  } elsif ($hdr =~ m@\AMZ@) {
    return "exe";
  } elsif ($hdr =~ m@\A\x80@) {  # OMF .obj object file generated by e.g. OpenWatcom.
    return "omf";
  } elsif ($hdr =~ m@\A\x4c\x01@) {  # COFF .obj obect file used on Win32.
    return "coff";
  } elsif ($hdr =~ m@\A(?:\xfe\xed\xfa[\xce|\xcf]|[\xce\xcf]\xfa\xed\xfe)@) {
    return "macho";  # Can  be executable, object etc.
  }
  for (;;) {
    ++$$lc_ref;
    if (defined($hdr)) {
      $hdr .= $_ if $hdr !~ m@\n@ and defined($_ = <$srcfh>);
      ($_, $hdr) = ($hdr, undef);
    } else {
      last if !defined($_ = <$srcfh>);
    }
    $$last_line_ref = $_;
    if (!m@\S@) {
    } elsif (m@\A\s*[.](?:text|file)(?:\s|/[*])@ or m@\s*/[*]@) {
      # !! TODO(pts): Detect C source file after end of the comment.
      # !! TODO(pts): Does GNU as support // as comment?
      return "as";
    } elsif (m@\A\s*[.](?:model\s|38[67])@i) {
      return "wasm";
    } elsif (m@\A\s*(?:bits\s|cpu\s|section\s|%)@i) {
      return "nasm";
    } elsif (m@\s*;@) {
    #  $can_be_as = 0;
    } else {
      chomp;
      die "error: assembly source file not detected (${$lc_ref}): $_\n";
      last
    }
  }
  undef
}

sub argv_escape_fn($) {
  my $filename = $_[0];
  substr($filename, 0, 0) = "./" if $filename =~ m@-@;  # TODO(pts): Win32 compatibility.
  $filename
}

# --- main().

if (!@ARGV or $ARGV[0] eq "--help") {
  print STDERR "as2nasm.pl: convert from i386 GNU as (AT&T) or WASM syntax, link with NASM\n",
               "This is free software, GNU GPL >=2.0. There is NO WARRANTY. Use at your risk.\n",
               "Usage: $0 [<flags>...] -o <output.prog> <input.s>\n",
               "Typical use case: compile C with GCC or OpenWatcom to assembly, then convert.\n",
               "Input syntax support is mostly limited to `gcc -S' and `wdis -a' output.\n";
  exit(!@ARGV);
}

my $i = 0;
my $cpulevel = 7;
my $outfn;
my $do_merge_tail_strings = 1;
my $data_alignment = 4;
my $outfmt = "prog";
my $nasm_prog = "nasm";
my $is_win32 = 0;  # TODO(pts): Autodetect it in .wasm source based on `extrn'. But then `-o' extension needs autodection.
my $do_add_libc = 1;  # Add libc when linking (final executable program, $outfmt eq "prog").
# TODO(pts): Add flag to inline elf.inc.nasm.
while ($i < @ARGV) {
  my $arg = $ARGV[$i++];
  if ($arg eq "--") {
    last
  } elsif (substr($arg, 0, 1) ne "-") {
    --$i; last;
  } elsif ($arg eq "-o" and $i == @ARGV) {
    die "fatal: missing value for flag: $arg\n";
  } elsif ($arg eq "-o") {  # Typically .nasm extension.
    $outfn = $ARGV[$i++];
  } elsif ($arg eq "-mmerge-tail-strings") {
    $do_merge_tail_strings = 1;
  } elsif ($arg eq "-mno-merge-tail-strings") {
    $do_merge_tail_strings = 0;
  } elsif ($arg eq "-m32" or $arg eq "--32") {
  } elsif ($arg eq "-mconsole" or $arg eq "-bwin32") {  # Win32 console application. -mconsole is MinGW GCC and TCC. -bwin32 is for OpenWatcom `owcc'.
    $is_win32 = 1;
  } elsif ($arg eq "-blinux") {  # Default. `-blinux' is for OpenWatcom `owcc'.
    $is_win32 = 0;
  } elsif ($arg eq "-nostdlib" or $arg eq "-fnostdlib") {  # -nostdlib is GCC, -fnostdlib is OpenWatcom.
    $do_add_libc = 0;
  } elsif ($arg =~ m@-march=(.*)\Z(?!\n)@) {
    my $value = lc($1);
    if ($value eq "i386") { $cpulevel = 3 }
    elsif ($value eq "i486") { $cpulevel = 4 }
    elsif ($value eq "i586") { $cpulevel = 5 }
    elsif ($value eq "i686") { $cpulevel = 6 }
    else { $cpulevel = 7 }  # Any instructions allowed.
  } elsif ($arg =~ m@-malign=(.*)\Z(?!\n)@) {  # Data section alignment.
    my $value = $1;
    # Allowed values: 0, 1, 2, 4, 8, 16, 32.
    # Values larger than 32 are not supported by elf.inc.nasm.
    die "fatal: bad data alignment: $arg\n" if
        $value !~ m@\A(?:0|[1-9]\d{0,8})\Z(?!\n)@ or
        ($value = int($value)) > 32 or
        ($value & ($value - 1));
    $data_alignment = $value > 1 ? $value : 1;
  } elsif ($arg eq "-S") {
    $outfmt = "nasm";
  } elsif ($arg eq "-c") {
    $outfmt = "elfobj";
  } elsif ($arg =~ m@--outfmt=(.*)\Z(?!\n)@) {
    $outfmt = lc($1);
    die "fatal: bad output format: $outfmt" if !
        ($outfmt eq "nasm" or $outfmt eq "elfobj" or $outfmt eq "elfprog" or $outfmt eq "prog");
  } elsif ($arg =~ m@--nasm=(.*)\Z(?!\n)@) {
    die "fatal: bad nasm program; $nasm_prog\n" if !length($nasm_prog);
    $nasm_prog = $1;
  } else {
    die "fatal: unknown flag: $arg\n";
  }
}
die "fatal: missing source file\n" if $i >= @ARGV;
die "fatal: too many source files, only one allowed\n" if $i > @ARGV + 1;
my $srcfn = $ARGV[$i];
die "fatal: missing NASM-assembly output file\n" if !defined($outfn);
if ($outfmt eq "elfprog") {
  die "fatal: --outfmt=elfprog conflicts with -bwin32; use --outfmt=prog instead\n" if $is_win32;
  $outfmt = "prog";
}

my @unlink_fns;
my $srcfh;
die "fatal: open assembly source file: $srcfn: $!\n" if !open($srcfh, "<", $srcfn);
binmode($srcfh);
my $nasmfn = $outfn;
if ($outfmt ne "nasm") {
  $nasmfn = "$outfn.tmp.nasm";
  push @unlink_fns, $nasmfn;
}
my $nasmfh;
die "fatal: open NASM-assembly output file: $nasmfn: $!\n" if !open($nasmfh, ">", $nasmfn);
binmode($nasmfh);

my $first_line;
my $lc = 0;
my $srcfmt = detect_source_format($srcfh, \$first_line, \$lc);
if (defined($srcfmt) and $srcfmt eq "omf") {  # Run `wdis' to get (dis)assembly of the WASM syntax.
  close($srcfh);
  my $wasmfn = "$outfn.tmp.wdis";  # TODO(pts): Remove temporary files upon exit.
  push @unlink_fns, $wasmfn;
  my @wdis_cmd = ("wdis", "-a", argv_escape_fn($srcfn));
  print STDERR "info: running wdis_cmd: @wdis_cmd >$wasmfn\n";
  {
    my $saveout;
    die if !open($saveout, ">&", \*STDOUT);
    die "fatal: open: $wasmfn: $!\n" if !open(STDOUT, ">", $wasmfn);
    die "fatal: wdis_cmd failed: @wdis_cmd\n" if system(@wdis_cmd);
    die if !open(STDOUT, ">&", $saveout);
    close($saveout);
  }
  $srcfn = $wasmfn;
  die "fatal: open assembly source file: $srcfn: $!\n" if !open($srcfh, "<", $srcfn);
  binmode($srcfh);
  $srcfmt = detect_source_format($srcfh, \$first_line, \$lc);
}
die "fatal: source file format not recognized: $srcfn\n" if !defined($srcfmt);
die "fatal: file format $srcfmt is not assembly source: $srcfn\n" if $srcfmt ne "as" and $srcfmt ne "wasm" and $srcfmt ne "nasm";

my $errc = 0;
my $rodata_strs = $do_merge_tail_strings ? [] : undef;
my $define_when_defined = {};  # This won't work for multiple source files.
my $common_by_label = {};
my $mydirp = ($0 =~ m@\A(.*/)@s ? $1 : "");  # TODO(pts): Win32 compatibility.
$mydirp = "" if $mydirp =~ m@\A[.]/+@;
print_nasm_header($nasmfh, $cpulevel, $data_alignment, $is_win32, $mydirp);
--$lc;  # We reuse $first_line.
my $is_start_found = 0;
if ($srcfmt eq "as") {
  print STDERR "info: converting from GNU as to NASM syntax: $srcfn to $nasmfn\n";
  my $undefineds = {};
  $errc += as2nasm($srcfh, $nasmfh, $first_line, $lc, $rodata_strs, $is_win32, $undefineds, $define_when_defined, $common_by_label, \$is_start_found);
  print $nasmfh "\nsection .rodata\n" if $rodata_strs and @$rodata_strs;
  print_merged_strings_in_strdata($nasmfh, $rodata_strs, 1);
  if (%$undefineds) {
    print $nasmfh "\n";
    for my $label (sort(keys(%$undefineds))) {
      print $nasmfh "extern $label\n";
    }
  }
} elsif ($srcfmt eq "wasm") {
  print STDERR "info: converting from WASM to NASM syntax: $srcfn to $nasmfn\n";
  wasm2nasm($srcfh, $nasmfh, $first_line, $lc, $rodata_strs, $is_win32, \$is_start_found);
  print $nasmfh "\nsection .rodata\n" if $rodata_strs and @$rodata_strs;
  print_merged_strings_in_strdata($nasmfh, $rodata_strs, 0);
} elsif ($srcfmt eq "nasm") {  # Just copy the lines.
  print $nasmfh $first_line if defined($first_line);
  while (<$srcfh>) { print $nasmfh $_ }
}
print_commons($nasmfh, $common_by_label, $define_when_defined);  # Aggregate from multiple source files.
die "fatal: $errc error@{[qq(s)x($errc!=1)]} during as2nasm translation\n" if $errc;
print $nasmfh "\n_end\n";  # elf.inc.nasm
print $nasmfh "\n; __END__\n";
die "fatal: error writing NASM-assembly output\n" if !close($nasmfh);
close($srcfh);
if ($srcfmt eq "as" and $do_add_libc and $outfmt eq "prog") {  # Remove F_ prefix from global labels, for linking with libc.
  # TODO(pts): Do this renaming in general (not only for linking with libc).
  my $nasmgfn = "$outfn.tmp.nasmg";
  my $nasmgfh;
  die "fatal: open NASM source file: $nasmgfn: $!\n" if !open($nasmfh, "<", $nasmfn);
  die "fatal: open global-label-renamed NASM source file: $nasmgfn: $!\n" if !open($nasmgfh, ">", $nasmgfn);
  push @unlink_fns, $nasmgfn;
  my $had_start = 0;
  while (<$nasmfh>) {
    # TODO(pts): Use any NASM label syntax.
    s@(\A|[^.\w\@?\$])([FSL])_([.\w\@?\$]+)@ $2 eq "F" ? "$1\$$3" : "$1\$_\$\x40$3" @ge if !m@'@;  # Remove F_ prefix from global labels, for linking with libc.
    $had_start = 1 if $_ eq "\$_start:\n";
    print $nasmgfh $_ unless $had_start and $_ eq "_start:\n";   # Don't add duplice `_start:' label.
  }
  die "fatal: error writing to global-label-renamed NASM source file\n" if !close($nasmgfh);
  close($nasmfh);
  $nasmfn = $nasmgfn;
}

if ($outfmt eq "prog" or $outfmt eq "elfobj") {
  unlink($outfn);
  my $nasmfmt = ($outfmt eq "prog" ? "bin" : "elf");  # With `-f bin', elf.inc.nasm or pe.inc.nasm will do the linking.
  my $do_extract_undefineds = ($outfmt eq "prog" and $do_add_libc);
  my @nasm_link_cmd = ($nasm_prog, "-O999999999", "-w+orphan-labels", "-f", $nasmfmt);
  my $saveerr;
  my $cmd_suffix = "";
  my $errfn;
  # TODO(pts): Also redirect on -Werror (turn NASM warnings to errors).
  my $nasm_link_cmd_i = @nasm_link_cmd;
  my $is_nostart_first = ($do_extract_undefineds and !$is_start_found);
  if ($do_extract_undefineds) {
    # We redirect stderr, because NASM 0.98.39 -E for error file is -Z in newer versions.
    $errfn = "$outfn.tmp.nasmerr";
    push @unlink_fns, $errfn;
    $cmd_suffix = " 2>$errfn";
    die if !open($saveerr, ">&", \*STDERR);
    die "fatal: open: $errfn: $!\n" if !open(STDERR, ">", $errfn);
    push @nasm_link_cmd, "-D_PROG_NO_START" if $is_nostart_first;
  }
  push @nasm_link_cmd, "-o", argv_escape_fn($outfn), argv_escape_fn($nasmfn);
  { my $stderr = defined($saveerr) ? $saveerr : \*STDERR;
    print $stderr "info: running nasm_link_cmd: @nasm_link_cmd$cmd_suffix\n";
    my $fh = select($stderr); $| = 1; select($fh);  # Flush.
  }
  my $is_nasm_link_ok = !system(@nasm_link_cmd);
  if (defined($saveerr)) {
    die if !open(STDERR, ">&", $saveerr);
    close($saveerr);
  }
  if (!$is_nasm_link_ok) {
    my $had_other_messages = 1;
    my $maybe_more_undefineds = 0;
    my %undefineds;
    my @undefineds;
    if ($do_extract_undefineds) {
      my $errfh;
      die "fatal: open $errfn: $!\n" if !open($errfh, "<", $errfn);
      my $do_hide_dots = 0;
      $had_other_messages = 0;
      while (<$errfh>) {
        if (m@\A(.*?:\d+: )@) {
          pos($_) = length($1);
          if (m@\Gerror: symbol `(.+)' not defined before use\Z@) {  # NASM 0.98.39 fatal error.
            $undefineds{$1} = 1; $do_hide_dots = 1; $maybe_more_undefineds = 1;
          } elsif (m@\Gerror: symbol `(.+)' undefined\Z@) {
            $undefineds{$1} = 1; $do_hide_dots = 1;
          } elsif (m@\G[.][.][.] @) {  # Provides macro source line.
            print STDERR $_ if !$do_hide_dots;
          } elsif (m@\Gerror: binary output format does not support external references\Z@) {
            $do_hide_dots = 1; $maybe_more_undefineds = 1;
          } elsif (m@\Gerror: phase error detected at end of assembly@) {  # With a `.'.
            $do_hide_dots = 0;
            if (!%undefineds) {
              $had_other_messages = 1;
              print STDERR $_;
            }
          } else {
            $do_hide_dots = 0; $had_other_messages = 1;
            print STDERR $_;
          }
        }
      }
      close($errfh);
      unlink($errfn);
      if (%undefineds or $maybe_more_undefineds) {
        @undefineds = sort(keys(%undefineds));
        push @undefineds, "+more" if $maybe_more_undefineds;
        if ($had_other_messages) {
          # Line number info is lost, but we try NASM again with libc, so it doesn't matter.
          print STDERR "error: undefined symbols: @undefineds\n";
        } elsif ($maybe_more_undefineds) {
          if (!$is_nostart_first) {
            print STDERR "info: running NASM again to find more undefined symbols: @undefineds\n";
          } else {
            print STDERR "fatal: assert: not all undefined symbols found\n";  # This must be an internal error hapening with NASM 0.98.39.
            $had_other_messages = 1;  # Will exit below.
          }
        } else {
          print STDERR "info: running NASM again to get symbols from libc: @undefineds\n";
        }
      }
    }
    die "fatal: nasm_link_cmd failed: @nasm_link_cmd\n" if $had_other_messages;
    splice @nasm_link_cmd, $nasm_link_cmd_i, 1 if $is_nostart_first;
    if ($maybe_more_undefineds) {
      splice @nasm_link_cmd, $nasm_link_cmd_i, 0, "-D_PROG_NO_START";
      die if !open($saveerr, ">&", \*STDERR);
      die "fatal: open: $errfn: $!\n" if !open(STDERR, ">", $errfn);
      { my $stderr = defined($saveerr) ? $saveerr : \*STDERR;
        print $stderr "info: running nasm_find_cmd: @nasm_link_cmd$cmd_suffix\n";
        my $fh = select($stderr); $| = 1; select($fh);  # Flush.
      }
      my $is_nasm_find_ok = !system(@nasm_link_cmd);  # Ignore return value, always go on.
      if (defined($saveerr)) {
        die if !open(STDERR, ">&", $saveerr);
        close($saveerr);
      }
      my $errfh;
      die "fatal: open $errfn: $!\n" if !open($errfh, "<", $errfn);
      $had_other_messages = 0;
      %undefineds = ();
      while (<$errfh>) {
        next if !m@\A(.*?:\d+: )@;
        pos($_) = length($1);
        if (m@\Gerror: symbol `(.+)' undefined\Z@) {
          $undefineds{$1} = 1;
        } elsif (m@\G[.][.][.] @) {  # Provides macro source line.
        } elsif (m@\Gerror: phase error detected at end of assembly@) {  # With a `.'.
        } else {
          print STDERR $_;
          $had_other_messages = 1;
        }
      }
      close($errfh);
      unlink($errfn);
      # TODO(pts): Report these errors.
      die "fatal: nasm_find_cmd failed: @nasm_link_cmd\n" if $had_other_messages;
      @undefineds = sort(keys(%undefineds));
      print STDERR "info: running NASM again to get symbols from libc: @undefineds\n";
      splice @nasm_link_cmd, $nasm_link_cmd_i, 1;
    }
    my $nlifn = "$outfn.tmp.nasmlibc";
    my $nlifh;
    die "fatal: open libc includer NASM source file: $nlifn: $!\n" if !open($nlifh, ">", $nlifn);
    push @unlink_fns, $nlifn;
    print $nlifh "; .nasm libc includer source file generated by as2nasm\n\n";
    for my $label (@undefineds) {
      print $nlifh "%define __LIBC_NEED_$label\n";
    }
    my $win32def = $is_win32 ? "%define __LIBC_WIN32\n" : "";
    print $nlifh qq(
$win32def%define __LIBC_INCLUDED
%macro __include_libc 0
%include '${mydirp}minilibc32.nasm'
%endm
%define _PROG_BEFORE_END __include_libc
%macro _abi 2
  %define __LIBC_ABI_%1_%2  ; Example: `%define __LIBC_ABI_cc_rp3' is regparm(3) calling convention.
  %ifdef __LIBC_ABI_%1__val
    %ifnidn __LIBC_ABI_%1__val,%2
      %error Conflict in __LIBC_ABI_%1__val_: __LIBC_ABI_%1__val vs %2
      times -1 nop  ; Force error on NASM 0.98.39.
    %endif
  %else
    %define __LIBC_ABI_%1__val %2
  %endif
%endm
%define _PROG_MACRO_ABI_DEFINED
%include '$nasmfn'
);
    @undefineds = ();  # Save memory.
    die "fatal: error writing to libc includer NASM source file\n" if !close($nlifh);
    $nasm_link_cmd[-1] = argv_escape_fn($nlifn);
    print STDERR "info: running nasm_link_libc_cmd: @nasm_link_cmd\n";
    die "fatal: nasm_link_libc_cmd failed: @nasm_link_cmd\n" if system(@nasm_link_cmd);
  } elsif ($is_nostart_first) {  # Initial guess was incorrect, we need to run NASM again without -D_PROG_NO_START.
    splice @nasm_link_cmd, $nasm_link_cmd_i, 1;
    print STDERR "info: running nasm_link_fix_cmd: @nasm_link_cmd\n";
    die "fatal: nasm_link_fix_cmd failed: @nasm_link_cmd\n" if system(@nasm_link_cmd);
  }
  if ($outfmt eq "prog") {  # Make it executable.
    # TODO(pts): Ignore this on Win32 (?).
    my @st = stat($outfn);
    if (@st) {
      my $new_mode = ((($st[2] & 0777) | 0111) & ~umask());
      die "fatal: chmod $outfn: $!\n" if !chmod($new_mode, $outfn);
    }
    my $size = -s($outfn);
    $size = "?" if !defined($size);
    my $target = $is_win32 ? "Win32" : "Linux i386";
    print "info: created $target program: $outfn ($size bytes)\n";
  }
}

# TODO(pts): Do it even on failure.
for my $filename (@unlink_fns) { unlink($filename); }

__END__
