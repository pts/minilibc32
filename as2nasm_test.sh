#! /bin/sh --
# by pts@fazekas.hu at Wed Nov 30 02:48:37 CET 2022
#

set -ex
#nasm-0.98.39 -O9 -f elf -o x86_32.o x86_32.nasm ||:
#nasm -O9 -f elf -o x86_32.o x86_32.nasm && ld -s -m elf_i386 -o x86_32 x86_32.o && ./x86_32 && echo OK && objdump -d x86_32 >x86_32.d || exit 1
# -w+orphan-labels is to detect assembly instructions without arguments not recognized by NASM.
nasm-0.98.39 -w+orphan-labels -O9 -f elf -o x86_32.o x86_32.nasm && ld --fatal-warnings -s -m elf_i386 -o x86_32 x86_32.o && ./x86_32 || exit 1  # && echo OK &&
objdump -d x86_32 >x86_32.d
perl -pi -e 's@^x86_32\w*(:[ \t]+file format )@$1@' x86_32.d  # For shorter diffs.
as -32 -march=core2+3dnow --fatal-warnings -o x86_32a.o x86_32.s && ld --fatal-warnings -s -m elf_i386 -o x86_32a x86_32a.o && ./x86_32a || exit 1  # && echo OK &&
objdump -d x86_32a >x86_32a.d
perl -pi -e 's@^x86_32\w*(:[ \t]+file format )@$1@' x86_32a.d  # For shorter diffs.
diff -U3 x86_32.d x86_32a.d

./as2nasm.pl <x86_32.s >x86_32c.nasm; nasm-0.98.39 -w+orphan-labels -O9 -f elf -o x86_32c.o x86_32c.nasm && ld --fatal-warnings -s -m elf_i386 -o x86_32c x86_32c.o && ./x86_32c || exit 1  # && echo OK &&
objdump -d x86_32c >x86_32c.d
perl -pi -e 's@^x86_32\w*(:[ \t]+file format )@$1@' x86_32c.d  # For shorter diffs.
diff -U3 x86_32.d x86_32c.d

if test $# != 0; then
  grep -F "$1" x86_32a.d ||:
  grep -F "$1" x86_32.d ||:
fi

: "$0" OK.
