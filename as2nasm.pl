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
# (`label:' and `db: ...') in `section .rodata.str1.1' (GCC, GNU as; already
# converted to db) or `CONST SEGMENT' (OpenWatcom WASM). It will be cleared
# as a side effect.
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
          else { print STDERR "($9)"; $has_error = 1; "" }
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
        print $outfh $rodata_strs->[$pi] if !exists($mapi{$pi});
      }
      if ($lofs != $oldofss[$i] or exists($mapi{$i})) {
        if (exists($mapi{$i})) {
          # !! TODO(pts): Find a later, closer label, report relative offset there.
          #print STDERR "$label equ __strs+$ofs  ; old=$lofs\n";
          print $outfh "$label equ __strs+$ofs  ; old=$lofs\n";
        } else {
          my $dofs = $lofs - $oldofss[$i];
          #print $outfh "$label equ \$+$dofs\n";
          print STDERR "$label equ \$+$dofs\n";
        }
      } else {
        #print STDERR "$label:\n";
        print $outfh "$label:\n";
      }
    }
    for (; $pi < @$rodata_strs; ++$pi) {
      #print STDERR "$rodata_strs->[$pi]\n" if !exists($mapi{$pi});
      print $outfh $rodata_strs->[$pi] if !exists($mapi{$pi});
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

sub print_nasm_header($$$$) {
  my($outfh, $cpulevel, $data_alignment, $mydirp) = @_;
  #my $data_alignment = ...;  # Configurable here. =1 is 3 bytes smaller, =4 is faster. TODO(pts): Modify the owcc invocation as well.
  die "fatal: invalid characters in directory: $mydirp\n" if $mydirp =~ y@['\r\n]@@;  # Bad for %include arg.
  print $outfh qq(; .nasm source file generated by as2nasm\nbits 32
%ifidn __OUTPUT_FORMAT__, elf  ; Make it work without elf.inc.nasm.
  section .text align=1
  section .rodata align=$data_alignment
  section .data align=$data_alignment
  section .bss align=$data_alignment
  %macro _end 0
  %endm
%else
  %include '${mydirp}elf.inc.nasm'  ; To make `nasm -f bin' produce an ELF executable program.
  %define _ELF_PROG_CPU_UNCHANGED
  _elf_start 32, Linux, $data_alignment|sect_many|shentsize
%endif
\n);
  # After elf.inc.nasm, because it may modify the CPU level.
  my $cpulevel_str = ($cpulevel > 6 ? "" : $cpulevel >= 3 ? "${cpulevel}86" : "386");  # "prescott" would also work for $cpulevel > 6;
  print $outfh "cpu $cpulevel_str\n" if length($cpulevel_str);
  #print $outfh "\nsection .text\n";  # asm2nasm(...) will print int.
}

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

my %gp_regs = map { $_ => 1 } qw(al cl dl bl ah ch dh bh ax cx dx bx sp bp si di eax ecx edx ebx esp ebp esi edi);

my %as_string_escape1 = ("b" => "\x08", "f" => "\x0c", "n" => "\x0a", "r" => "\x0d", "t" => "\x09", "v" => "\x0b");

sub fix_label($$$$) {
  my($label, $bad_labels, $used_labels, $local_labels) = @_;
  if ($label =~ m@\A[.]L(\w+)\Z(?!\n)@) {  # Typically: .L1 and .LC0
    $label = "L_$1";
  } elsif ($label =~ m@\A([a-zA-Z_\@?][\w.\@?\$~#]*)\Z(?!\n)@) {  # Match NASM label.
    my $label2 = "S_$1";
    $label = exists($local_labels->{$label2}) ? $label2 : "F_$1";
  } else {
    push @$bad_labels, $label;
    return "?";
  }
  $used_labels->{$label} = 1;
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
    $displacement = "+" . $displacement if length($regs);
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
sub as2nasm($$$$$$$$) {
  my($srcfh, $outfh, $first_line, $lc, $rodata_strs, $undefineds, $define_when_defined, $common_by_label) = @_;
  my %unknown_directives;
  my $errc = 0;
  my $is_comment = 0;
  my $section = ".text";
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
    s@/[*].*?[*]/@ @sg;  # !!! TODO(pts): Parse .string "/*"
    $is_comment = 1 if s@/[*].*@@s;  # Start of multiline comment.
    s@\A[\s;]+@@;
    s@[\s;]+\Z(?!\n)@@;
    if (!m@"@) {
      s@\s+@ @g;
    } else {
      s@\s+|("(?:[^\\"]+|\\.)*")@ defined($1) ? $1 : " " @ge;  # Keep quoted spaces intact.
    }
    if (s@;.*@@s) {
      ++$errc;
      # TODO(pts): Support multiple instructions per line.
      print STDERR "error: multiple instructions per line, all but the first ignored ($lc): $_\n";
    }
    next if !length($_);
    my @bad_labels;
    if (s@\A([^\s:,]+): *@@) {
      if (!length($section)) {
        ++$errc;
        print STDERR "error: label outside section ($lc): $_\n";
      }
      my $label = fix_label($1, \@bad_labels, $used_labels, \%local_labels);
      if (length($section) == 1) {
        push @$rodata_strs, "$label:";
      } else {
        print $outfh "$label:\n";
        print $outfh "_start:\n" if $label eq "F__start";  # !! TODO(pts): Indicate the entry point smarter.
      }
      $defined_labels{$label} = 1;
      if (exists($define_when_defined->{$label})) {
        my $label1 = $define_when_defined->{$label};
        print $outfh "$label1 equ $label\n";
        $defined_labels{$label1} = 1;
      }
    }
    if (m@\A[.]@) {
      if (m@\A[.](?:file "|size |type |loc |cfi_|ident ")@) {
        # Ignore this directive (.file, .size, .type).
      } elsif (m@\A([.](?:text|data|rodata))\Z@) {
        $section = $1;
        print $outfh "section $section\n";
      } elsif (m@\A[.]globl ([^\s:,]+)\Z@) {
        my $label = fix_label($1, \@bad_labels, $used_labels, \%local_labels);
        print $outfh "global $label\n";
        print $outfh "global _start\n" if $label eq "F__start";  # !! TODO(pts): Indicate the entry point smarter.
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
        my $label = fix_label($1, \@bad_labels, $used_labels, \%local_labels);
        if (exists($defined_labels{$label})) {
          ++$errc;
          print STDERR "error: label defined before .local ($lc): $label\n";
        }
        if ($label =~ m@\AL_@) {
          ++$errc;
          print STDERR "error: local-prefix label cannot be declared .local ($lc): $label\n";
        } elsif (exists($global_labels{$label})) {  # Must start with F_.
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
      } elsif (m@\A[.]section [.]rodata[.]str1[.]1 *(?:,|\Z)@) {
        if ($rodata_strs) {
          $section = "S";
        } else {
          $section = ".rodata";  # !! Any better? Move all after .rodata?
          print $outfh "section $section\n";
        }
      } elsif (m@\A[.]section [.]rodata\Z@) {
        $section = ".rodata";
        print $outfh "section $section\n";
      } elsif (m@\A[.]section [.]note[.]GNU-stack[,]@) {
        # Non-executable stack marker: .section .note.GNU-stack,"",@progbits
        # !! respect it.
        $section = "";
      } elsif (m@\A[.]extern ([^\s:,]+)\Z@) {  # GCC doesn't write these.
        my $label = fix_label($1, \@bad_labels, $used_labels, \%local_labels);
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
        if (length($section) <= 1) {
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
          my $label = fix_label($1, \@bad_labels, $used_labels, \%local_labels);
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
        if (length($section) <= 1) {
          ++$errc;
          print STDERR "error: .align outside section ($lc): $_\n";
        } elsif ($section eq ".bss") {
          # We'd need `alignb'. Does it make sense? We don't even support .bss directly.
          print STDERR "error: .align in .bss ignored ($lc): $_\n" if !exists($unknown_directives{".align/bss"});
          $unknown_directives{".align/bss"} = 1;
        } else {
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
        if (length($section) <= 1) {
          ++$errc;
          print STDERR "error: .$inst1 outside section ($lc): $_\n";
        }
        my $inst = $inst1 eq "byte" ? "db" : $inst1 eq "value" ? "dw" : $inst1 eq "long" ? "dd" : "d?";
        print $outfh "$inst $expr\n";
      } elsif (m@\A[.]((string)|ascii) "((?:[^\\"]+|\\.)*)"\Z@s) {
        my($inst1, $inst2, $data) = ($1, $2, $3);
        if (!length($section)) {
          ++$errc;
          print STDERR "error: .$inst1 outside section ($lc): $_\n";
        }
        # GNU as 2.30 does the escaping like this.
        $data =~ s@\\(?:([0-3][0-7]{2})|[xX]([0-9a-fA-F]{1,})|([bfnrtv])|(.))@
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
            print $outfh "db $data\n";
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
        if (s@\A[*]@@) {}
        elsif (!m@\A[\$]@) { s@\A@\$@ }  # Relative immediate syntax for `jmp short' or `jmp near'.
      }
      #
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
      print $outfh "$inst$instwd$args\n";
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
sub wasm2nasm($$$$$) {
  my($srcfh, $outfh, $first_line, $lc, $rodata_strs) = @_;
  my $section = ".text";
  my $segment = "";
  my $bss_org = 0;
  my $is_end = 0;
  my %segment_to_section = qw(_TEXT .text  CONST .rodata  CONST2 .rodata  _DATA .data  _BSS .bss);
  my %directive_to_segment = qw(.code _TEXT  .const CONST2  .data _DATA  .data? _BSS);  # TODO(pts): Is there a way for CONST2?
  my $end_expr;
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
    }
    if ($is_instr) {
      die "$0: unsupported instruction in non-.text ($lc): $_\n" if $section ne ".text";
      die "$0: unsupported quote in instruction ($lc): $_\n" if m@'@;  # Whitespace is already gone.
      if (s~^(jmp|call) near ptr (?:FLAT:)?~$1 \$~) {
      } elsif (s@^(j[a-z]+|loop[a-z]*) ([^\[\],\s]*)$@$1 \$$2@) {   # Add $ in front of jump target label.
      } else {
        s@, *@, @g;
        s@ (byte|word|dword) ptr (?:([^\[\],\s]*)\[(.*?)\]|FLAT:([^,]+))@
            my $dspl = length($2) ? "+$2" : "";
            " $1 " . (defined($2) ? "[$3$dspl]" : "[\$$4]") @ge;
        s@([\s,])([^\[\],\s]+)\[(.*?)\]@${1}[$3+$2]@g;  # `cmp al, 42[esi]'   -->  `cmp al, [esi+42]'.
        s@([-+])FLAT:([^,]+)@$1\$$2@g;
        s@\boffset (?:FLAT:)?([^,+\-\[\]*/()<>\s]+)@ \$$1@g;
      }
      if ($rodata_strs and $segment eq "CONST") {  # C string literals.
        push @$rodata_strs, $_;
      } else {
        print $outfh "$_\n";
      }
    } elsif (m@^[.]@) {
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
    } elsif (m@^[^\s:\[\],+\-*/]+:$@) {  # Label.  TODO(pts): Convert all labels, e.g. eax to $eax.
      if ($rodata_strs and $segment eq "CONST") {
        push @$rodata_strs, "\$$_";
      } else {
        print $outfh "_start:\n" if $_ eq "_start_:";  # Add extra start label for entry point.
        print $outfh "\$$_\n";
      }
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
    } elsif (m@^([^\s:\[\],+\-*/]+) LABEL BYTE$@ and $section eq ".bss") {
      print $outfh "\$$1:\n";
    } elsif (m@^end(?: ([^\s:\[\],+\-*/]+))?$@i) {
      $end_expr = $1;
      $is_end = 1;
    } elsif (m@^public ([^\s:\[\],+\-*/]+)$@i) {
      print $outfh "global \$$1\n";
    } elsif (m@^extrn ([^\s:\[\],+\-*/]+)(?::byte)?$@i) {
      print $outfh "extern \$$1\n";
    } elsif (!length($_) or m@^DGROUP GROUP@ or m@^ASSUME @) {  # Ignore.
    } else {
      die "fatal: unsupported WASM instruction ($lc): $_\n" ;
    }
  }
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
my $outfmt = "elfprog";
my $nasm_prog = "nasm";
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
        ($outfmt eq "nasm" or $outfmt eq "elfobj" or $outfmt eq "elfprog");
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
    die "fatal: open: $wasmfn\n: $!" if !open(STDOUT, ">", $wasmfn);
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
my $mydirp = ($0 =~ m@\A(.*/)@ ? $1 : "");  # TODO(pts): Win32 compatibility.
$mydirp = "" if $mydirp =~ m@\A[.]/+@;
print_nasm_header($nasmfh, $cpulevel, $data_alignment, $mydirp);
--$lc;  # We reuse $first_line.
if ($srcfmt eq "as") {
  print STDERR "info: converting from GNU as to NASM syntax: $srcfn to $nasmfn\n";
  my $undefineds = {};
  $errc += as2nasm($srcfh, $nasmfh, $first_line, $lc, $rodata_strs, $undefineds, $define_when_defined, $common_by_label);
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
  wasm2nasm($srcfh, $nasmfh, $first_line, $lc, $rodata_strs);
  print $nasmfh "\nsection .rodata\n" if $rodata_strs and @$rodata_strs;
  print_merged_strings_in_strdata($nasmfh, $rodata_strs, 0);
} elsif ($srcfmt eq "nasm") {  # Just copy the lines.
  print $nasmfh $first_line if defined($first_line);
  while (<$srcfh>) { print $nasmfh $_ }
}
print_commons($nasmfh, $common_by_label, $define_when_defined);  # !! Do it in the caller, after aggregating from multiple source files.
die "fatal: $errc error@{[qq(s)x($errc!=1)]} during as2nasm translation\n" if $errc;
print $nasmfh "\n_end\n";  # elf.inc.nasm
print $nasmfh "\n; __END__\n";
die "fatal: error writing NASM-assembly output\n" if !close($nasmfh);
close($srcfh);

if ($outfmt eq "elfprog" or $outfmt eq "elfobj") {
  unlink($outfn);
  my $nasmfmt = ($outfmt eq "elfprog" ? "bin" : "elf");  # With `-f bin', elf.inc.nasm will do the linking. !!
  my @nasm_link_cmd = ($nasm_prog, "-O999999999", "-w+orphan-labels", "-f", $nasmfmt, "-o", argv_escape_fn($outfn), argv_escape_fn($nasmfn));
  print STDERR "info: running nasm_link_cmd: @nasm_link_cmd\n";
  die "fatal: nasm_link_cmd failed: @nasm_link_cmd\n" if system(@nasm_link_cmd);
  if ($outfmt eq "elfprog") {  # Make it executable.
    # TODO(pts): Ignore this on Win32 (?).
    my @st = stat($outfn);
    if (@st) {
      my $new_mode = ((($st[2] & 0777) | 0111) & ~umask());
      die "fatal: chmod $outfn: $!\n" if !chmod($new_mode, $outfn);
    }
  }
}

# TODO(pts): Do it even on failure.
for my $filename (@unlink_fns) { unlink($filename); }


__END__
