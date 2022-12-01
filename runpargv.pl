#! /usr/bin/perl -w
# by pts@fazekas.hu at Thu Dec  1 16:35:56 CET 2022
use integer;
use strict;

my @chars = ("a", " ", "\"", "\\");

my @aa = ("");
for my $c1 (@chars) { push @aa, $c1 }
for my $c1 (@chars) { for my $c2 (@chars) { push @aa, $c1 . $c2 } }
for my $c1 (@chars) { for my $c2 (@chars) { for my $c3 (@chars) { push @aa, $c1 . $c2 . $c3 } } }
for my $c1 (@chars) { for my $c2 (@chars) { for my $c3 (@chars) { for my $c4 (@chars) { push @aa, $c1 . $c2 . $c3 . $c4 } } } }
for my $c1 (@chars) { for my $c2 (@chars) { for my $c3 (@chars) { for my $c4 (@chars) { for my $c5 (@chars) { push @aa, $c1 . $c2 . $c3 . $c4 . $c5 } } } } }
for my $c1 (@chars) { for my $c2 (@chars) { for my $c3 (@chars) { for my $c4 (@chars) { for my $c5 (@chars) { for my $c6 (@chars) { push @aa, $c1 . $c2 . $c3 . $c4 . $c5 . $c6 } } } } } }

my @cmd = @ARGV;
@cmd = ("./pargv") if !@cmd;
my $prefix = "";
$prefix = pop(@cmd) if @cmd and substr($cmd[-1], 0, 1) eq "-";

my $i = 0;
for my $arg (@aa) {
  ++$i;
  my @args = ("${prefix}s$i", $arg, "e$i");
  my $full_cmd_joined = join(" ", map { "($_)" } @args);
  my @full_cmd = (@cmd, @args);
  print "--- r$i $full_cmd_joined\n";
  { my $fh = select(STDOUT); $| = 1; select($fh); }  # Flush.
  die "fatal: full_cmd failed: @full_cmd\n" if system(@full_cmd);
}
print "--- end\n";
 
  
