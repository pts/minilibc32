#! /usr/bin/perl -w
#
# as2nasm.pl: convert from GNU as (AT&T) syntax to NASM syntax
# by pts@fazekas.hu at Tue Nov 29 01:46:33 CET 2022
#

BEGIN { $^W = 1 }
use integer;
use strict;

# !! doc: It's not the goal to get bitwise identical machine code output (but it's nice to have if easy), but to get same-size instructions wherever possible, maybe different encoding (e.g. `mov eax, ebx' has 2 encodings).
# !! Treat nasm warnings as errors (everything on stderr).
# !! Support `gcc -masm=intel' and `clang --x86-asm-syntax=intel'.
# !! Emit `push dword eax' without the `dword', keep it with `r/m, imm' args.
# !! When linking, unify strings in `.section .rodata.str1.1,"aMS",@progbits,1' by tail.
# !! What does it mean? .section        .text.unlikely,"ax",@progbits

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

sub print_nasm_header($$) {
  my($outfh, $cpulevel) = @_;
  print $outfh "bits 32\n";
  print $outfh "cpu ${cpulevel}86\n" if $cpulevel >= 3 and $cpulevel <= 6;
  print $outfh "section .text align=1\n";
  print $outfh "section .bss align=4\n";
  print $outfh "section .data align=4\n";
  print $outfh "section .rodata align=4\n";
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
sub as2nasm($$) {
  my($infh, $outfh) = @_;
  my %unknown_directives;
  my $errc = 0;
  my $is_comment = 0;
  print $outfh "\nsection .text\n";
  while (<STDIN>) {
    if ($is_comment) {
      next if !s@\A.*[*]/@@s;  # End of multiline comment.
      $is_comment = 0;
    }
    y@[\r\n]@@;
    s@/[*].*?[*]/@ @sg;
    $is_comment = 1 if s@/[*].*@@s;  # Start of multiline comment.
    s@\s+@ @g;
    s@\A[ ;]+@@;
    s@[ ;]+\Z(?!\n)@@;
    if (s@;.*@@s) {
      ++$errc;
      # TODO(pts): Support multiple instructions per line.
      print STDERR "error: multiple instructions per line, all but the first ignored ($.): $_\n";
    }
    next if !length($_);
    my @bad_labels;
    if (s@\A([^\s:,]+): *@@) {
      my $label = fix_label($1, \@bad_labels);
      print $outfh "$label:\n";
      print $outfh "_start:\n" if $label eq "F__start";  # !! TODO(pts): Indicate the entry point smarter.
      next if !length($_);
    }
    if (m@\A[.]@) {
      if (m@\A[.](?:file "|size |type )@) {
        # Ignore this directive.
      } elsif (m@\A[.](?:text|data|rodata)\Z@) {
        print $outfh "section .text\n";
      } elsif (m@\A[.]globl ([^\s:,]+)\Z@) {
        my $label = fix_label($1, \@bad_labels);
        print $outfh "global $label\n";
        print $outfh "global _start:\n" if $label eq "F__start";  # !! TODO(pts): Indicate the entry point smarter.
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
      my $inst = $1;
      $inst = "wait" if $inst eq "fwait";
      while (exists($prefix_insts{$inst})) {
        my $suffix = ($inst eq "wait" or !length($_)) ? "\n" : " ";
        print $outfh $inst, $suffix;
        $inst = s@\A([a-z][a-z0-9]*) *@@ ? $1 : "";
        $inst = "wait" if $inst eq "fwait";
      }
      if (!length($inst)) {
        next if !length($_);
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
          next
        } elsif (@args == 1 and exists($reg32_to_index{"e$args[0]"})) {
          print $outfh sprintf("db 0x66, 0x0f, 0x1f, 0x%02x  ; nop %s\n", 0xc0 | $reg32_to_index{"e$args[0]"}, $args[0]);
          next
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
          next
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
    }
    for my $label (@bad_labels) {
      ++$errc;
      print STDERR "error: bad label syntax ($.): $label\n";
    }
  }
  $errc
}

my $outfh = \*STDOUT;
my $cpulevel = 7;  # !! Override, e.g. -march=i386.
print_nasm_header($outfh, $cpulevel);
my $errc = as2nasm(\*STDIN, $outfh);
print $outfh "extern F_callee\n";  # !! Autodetect.
print $outfh "extern F_gf\n";  # !! Autodetect.
die "fatal: $errc error@{[qq(s)x($errc!=1)]} during as2nasm translation\n" if $errc;
print $outfh "\n; __END__\n";
