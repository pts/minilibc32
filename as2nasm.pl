#! /usr/bin/perl -w
#
# as2nasm.pl: convert from GNU as (AT&T) syntax to NASM syntax
# by pts@fazekas.hu at Tue Nov 29 01:46:33 CET 2022
#
# !! do we need to reorder global variables by alignment (or does GCC already emit in the correct, decreasing order -- not for .comm)?
# !! doc: It's not the goal to get bitwise identical machine code output (but it's nice to have if easy), but to get same-size instructions wherever possible, maybe different encoding (e.g. `mov eax, ebx' has 2 encodings).
# !! Treat nasm warnings as errors (everything on stderr).
# !! Support `gcc -masm=intel' and `clang --x86-asm-syntax=intel'.
# !! What does it mean? .section        .text.unlikely,"ax",@progbits
#
# ./as2nasm.pl <mininasm.gcc75.s >t.nasm; nasm -O19 -f elf -o t.o t.nasm && ld --fatal-warnings -s -m elf_i386 -o t.prog t.o && sstrip.static t.prog && ls -ld t.prog && ./t.prog
# ./as2nasm.pl <mininasm.gcc75.s >t.nasm; nasm -O19 -f bin -o t.prog t.nasm && chmod +x t.prog && ls -ld t.prog && ./t.prog
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
          } elsif (defined($7)) { $ofs += length($6) - 2; $6 }
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

sub print_nasm_header($$) {
  my($outfh, $cpulevel) = @_;
  print $outfh "bits 32\n";
  print $outfh "cpu ${cpulevel}86\n" if $cpulevel >= 3 and $cpulevel <= 6;
  # !! better match https://www.nasm.us/xdoc/2.09.10/html/nasmdoc7.html
#section .text    progbits  alloc   exec    nowrite  align=16
#section .rodata  progbits  alloc   noexec  nowrite  align=4
#section .lrodata progbits  alloc   noexec  nowrite  align=4
#section .data    progbits  alloc   noexec  write    align=4
#section .ldata   progbits  alloc   noexec  write    align=4
#section .bss     nobits    alloc   noexec  write    align=4
#section .lbss    nobits    alloc   noexec  write    align=4
#section .tdata   progbits  alloc   noexec  write    align=4    tls
#section .tbss    nobits    alloc   noexec  write    align=4    tls
#section .comment progbits  noalloc noexec  nowrite  align=1
#section other    progbits  alloc   noexec  nowrite  align=1

  # !! These values are needed for as2nasm_test.sh
  #print $outfh "section .text align=1\n";
  #print $outfh "section .rodata align=4\n";
  #print $outfh "section .data align=4\n";  # !!! Why is this .data aligned to 0x1000?
  #print $outfh "section .bss align=4 nobits\n";

  #print $outfh "section .text align=1\n";
  #print $outfh "section .rodata align=1\n";
  #print $outfh "section .data align=1\n";  # !!! Why is this .data aligned to 0x1000?
  #print $outfh "section .bss align=1 nobits\n";
  #print $outfh "%define _end\n";

  if (0) {
    print $outfh "section .text align=1\n";
    print $outfh "section .rodata align=32\n";
    print $outfh "section .data align=4\n";  # !!! Why is this .data aligned to 0x1000? if not .comm
    print $outfh "section .bss align=32 nobits\n";
    print $outfh "%define _end\n";
  } else {
    my $data_alignment = 4;
    print $outfh "%include 'elf.inc.nasm'\n_elf_start 32, Linux, $data_alignment|sect_many|shentsize\n\n";
  }

  print $outfh "section .text\n";
}

sub fix_label($$) {
  my($label, $bad_labels) = @_;
  if ($label =~ m@\A[.]L(\w+)\Z(?!\n)@) {  # Typically: .LC0
    return "L_$1";
  } elsif ($label =~ m@\A([a-zA-Z_\@?][\w.\@?\$~#]*)\Z(?!\n)@) {  # Match NASM label.
    return "F_$1";
  } else {
    push @$bad_labels, $label;
    return "?";
  }
}

sub fix_labels($$) {
  my($s, $bad_labels) = @_;
  die if !defined($s);
  $s =~ s~([0-9][0-9a-zA-Z]*)|([.a-zA-Z_\@?][\w.\@?\$\~#]*)~ my $s2 = $2; my $label; defined($1) ? $1 : fix_label($2, $bad_labels) ~ge;
  $s
}

sub fix_ea($$$$) {
  my ($segreg, $displacement, $regs, $bad_labels) = @_;
  # We could remove whitespace from $displacement and $regs, but we don't care.
  $regs =~ y@% @@d;
  $regs =~ s@,@+@;  # Only the first ','.
  $regs =~ s@,@*@;  # Only the second ','.
  # We could do more syntax checks here.
  if ($displacement =~ m@[^ ]@) {
    $displacement = "+" . $displacement if length($regs);
    $displacement = fix_labels($displacement, $bad_labels);
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
# subset of GNU as syntax, mostly the one generated by GCC.
#
# !! Rename local labels (L_* and also non-.globl F_) by file: L1_* F2_*.
sub as2nasm($$$) {
  my($infh, $outfh, $rodata_strs) = @_;
  my %unknown_directives;
  my $errc = 0;
  my $is_comment = 0;
  my $section = ".text";
  print $outfh "\nsection $section\n";
  while (<STDIN>) {
    if ($is_comment) {
      next if !s@\A.*[*]/@@s;  # End of multiline comment.
      $is_comment = 0;
    }
    y@[\r\n]@@;
    s@/[*].*?[*]/@ @sg;
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
      print STDERR "error: multiple instructions per line, all but the first ignored ($.): $_\n";
    }
    next if !length($_);
    my @bad_labels;
    if (s@\A([^\s:,]+): *@@) {
      if (!length($section)) {
        ++$errc;
        print STDERR "error: label outside section ($.): $_\n";
      }
      my $label = fix_label($1, \@bad_labels);
      if (length($section) == 1) {
        push @$rodata_strs, "$label:";
      } else {
        print $outfh "$label:\n";
        print $outfh "_start:\n" if $label eq "F__start";  # !! TODO(pts): Indicate the entry point smarter.
      }
    }
    if (m@\A[.]@) {
      if (m@\A[.](?:file "|size |type |loc |cfi_|ident ")@) {
        # Ignore this directive (.file, .size, .type).
      } elsif (m@\A([.](?:text|data|rodata))\Z@) {
        $section = $1;
        print $outfh "section $section\n";
      } elsif (m@\A[.]globl ([^\s:,]+)\Z@) {
        my $label = fix_label($1, \@bad_labels);
        print $outfh "global $label\n";
        print $outfh "global _start\n" if $label eq "F__start";  # !! TODO(pts): Indicate the entry point smarter.
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
      } elsif (m@\A[.]extern ([^\s:,]+)\Z@) {
        my $label = fix_label($1, \@bad_labels);
        #print $outfh "extern $label\n";  # !! TODO(pts): Conflicts with `global main' (e.g. main)?
        print STDERR "warning: extern ignored ($.): $_\n";
      } elsif (m@\A[.]local ([^\s:,]+)\Z@) {
        my $label = fix_label($1, \@bad_labels);
        print $outfh ";local $label\n";  # NASM doesn't need it.
      } elsif (m@\A[.]comm ([^\s:,]+), *(0|[1-9]\d*), *(0|[1-9]\d*)\Z@) {
        if (length($section) <= 1) {
          ++$errc;
          print STDERR "error: .comm outside section ($.): $_\n";
        }
        my ($size, $alignment) = ($2 + 0, $3 + 0);
        my $label = fix_label($1, \@bad_labels);
        print $outfh "section .bss\n";
        print $outfh "$label: resb $size\n";  # !! Allow multiple definintions (but not for .local). There is also the `common' directive for `nasm -f elf'.
        print $outfh "section $section\n";
      } elsif (m@\A[.]align (0|[1-9]*)\Z@) {
        if (length($section) <= 1) {
          ++$errc;
          print STDERR "error: .align outside section ($.): $_\n";
        }
        print STDERR "warning: align ignored ($.): $_\n" if !exists($unknown_directives{".align"});  # !!
        $unknown_directives{".align"} = 1;
      } elsif (m@\A[.](byte|value|long) (\S.*)\Z@) {  # !! 64-bit data? floating-point data?
        my $inst1 = $1;
        my $expr = fix_labels($2, \@bad_labels);
        if (length($section) <= 1) {
          ++$errc;
          print STDERR "error: .$inst1 outside section ($.): $_\n";
        }
        my $inst = $inst1 eq "byte" ? "db" : $inst1 eq "value" ? "dw" : $inst1 eq "long" ? "dd" : "d?";
        print $outfh "$inst $expr\n";
      } elsif (m@\A[.]((string)|ascii) "((?:[^\\"]+|\\.)*)"\Z@s) {
        my($inst1, $inst2, $data) = ($1, $2, $3);
        if (!length($section)) {
          ++$errc;
          print STDERR "error: .$inst1 outside section ($.): $_\n";
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
          print STDERR "error: unknown directive $d ignored ($.): $_\n";
          $unknown_directives{$d} = 1;
        }
      }
    } elsif (s@\A([a-z][a-z0-9]*) *@@) {
      if (length($section) <= 1) {
        ++$errc;
        print STDERR "error: instruction outside section ($.): $_\n";
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
        print STDERR "error: no instruction after prefix ($.): $_\n";
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
        elsif (m@\G\$([^(),]+)(?:, *|\Z)@gc) { push @args, fix_labels($1, \@bad_labels) }  # Immediate.
        elsif (m@\G(?:%([a-z]s) *: *)?(?:([^%(),]+)|([^%(),]*)\(([^()]+)\))(?:, *|\Z)@gc) { push @args, fix_ea($1, defined($2) ? $2 : $3, defined($2) ? "" : $4, \@bad_labels) }  # Effective address.
        elsif (m@\G([^,]*)(?:, *|\Z)@gc) {
          ++$errc;
          print STDERR "error: bad instruction argument ($.): $1\n";
          push @args, "?";
        } else {
          my $rest = substr($_, pos($_));
          die "fatal: assert: bad instruction argument ($.): $rest\n";
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
          print STDERR "error: nop argument too complex for NASM 0.98.39 ($.): $inst $_\n";
        }
      } elsif (exists($str_arg_insts{$inst})) {
        my $suffix = ((grep { $_ eq "al" } @args) ? "b" : "") . ((grep { $_ eq "ax" } @args) ? "w" : "") . ((grep { $_ eq "eax" } @args) ? "d" : "");
        if (length($suffix) != 1) {
          ++$errc;
          print STDERR "error: unrecognized string instruction size $suffix ($.): $inst $_\n";
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
        print STDERR "error: fisttpll args too complex for buggy NASM 0.98.39 ($.): $inst $_\n";
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
      print STDERR "error: instruction or directive expected ($.): $_\n";
    }
   check_labels:
    for my $label (@bad_labels) {
      ++$errc;
      print STDERR "error: bad label syntax ($.): $label\n";
    }
  }
  if (0 and $rodata_strs and @$rodata_strs) {  # For debugging: don't merge (optimize) anything.
    $section = ".rodata";
    print $outfh "section $section\n";
    for my $str (@$rodata_strs) {
      $str .= "\n";
      print $outfh $str;
    }
    @$rodata_strs = ();
  }
  $errc
}

my $outfh = \*STDOUT;
my $cpulevel = 7;  # !! Override, e.g. -march=i386.
my $do_merge_strings = 1;
my $rodata_strs = $do_merge_strings ? [] : undef;
print_nasm_header($outfh, $cpulevel);
my $errc = as2nasm(\*STDIN, $outfh, $rodata_strs);
print "section .rodata\n" if $rodata_strs and @$rodata_strs;
print_merged_strings_in_strdata($outfh, $rodata_strs, 1);
print $outfh "extern F_callee\n";  # !! Autodetect.
print $outfh "extern F_gf\n";  # !! Autodetect.
die "fatal: $errc error@{[qq(s)x($errc!=1)]} during as2nasm translation\n" if $errc;
print $outfh "\n_end\n";  # elf.inc.nasm
print $outfh "\n; __END__\n";
