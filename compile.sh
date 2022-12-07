#! /bin/sh --
# by pts@fazekas.hu at Sun Nov 27 13:52:44 CET 2022

if nasm-0.98.39 -v >/dev/null 2>&1; then
  NASM=nasm-0.98.39
else
  NASM=nasm
fi

if sstrip.static --version >/dev/null 2>&1; then
  SSTRIP=sstrip.static
else
  SSTRIP=sstrip
fi

GCC=gcc

set -ex

# For size comparisons of the file minilibc32.bin.
$NASM -O9 -f bin -DFEATURES_ALLOCA -o minilibc32.bin minilibc32.nasm
ls -ld minilibc32.bin

# Compile the libc for OpenWatcom Linux i386.
$NASM -O9 -f obj -o minilibc32.obj minilibc32.nasm
# Compile write(2)+exit(2) version (for hello-world benchmark).
$NASM -O9 -f obj -DFEATURES_WE -o minilibc32we.obj minilibc32.nasm
# Compile full version including 64-bit integers.
$NASM -O9 -f obj -DFEATURES_INT64 -o minilibc32f.obj minilibc32.nasm

# Compile the libc for GCC Linux i386.
$NASM -O9 -f elf -DFEATURES_ALLOCA -o minilibc32.o minilibc32.nasm
# Compile write(2)+exit(2) version (for hello-world benchmark).
$NASM -O9 -f elf -DFEATURES_WE -o minilibc32we.o minilibc32.nasm
# Compile full version including 64-bit integers.
$NASM -O9 -f elf -DFEATURES_INT64 -DFEATURES_ALLOCA -o minilibc32f.o minilibc32.nasm

# Compile the minilibc32.s fork with GNU as.
AS="$($GCC -print-prog-name=as)"
test "$AS"
"$AS" -32 -march=i386 -o minilibc32a.o minilibc32.s

# Compile programs test?ow with OpenWatcom (owcc).
owcc -blinux -fnostdlib -Os -s -fno-stack-check -march=i386 -W -Wall -Wextra -Werror -o test1ow test1.c minilibc32.obj
owcc -blinux -fnostdlib -Os -s -fno-stack-check -march=i386 -W -Wall -Wextra -Werror -o test2ow test2.c minilibc32f.obj

# Compile program test1gc with GCC (gcc).
#
# It works with or without -mregparm=3 (because regparm(3) is enforced for
# libc functions). Program File size differs though.
#
# GCC -m... and -f... flags are from
# https://github.com/pts/pts-xtiny/blob/778a3353bd7313a9c0ec72a599b0a11ce72abbf6/xtiny#L819-L862
GCCFLAGS='-D__LIBC_OMIT_ABITEST_DIVDI3 -m32 -mregparm=3 -fno-pic -fno-stack-protector -fomit-frame-pointer -fno-ident -ffreestanding -fno-builtin -fno-unwind-tables -fno-asynchronous-unwind-tables -nostdlib -nostdinc -Os -falign-functions=1 -mpreferred-stack-boundary=2 -falign-jumps=1 -falign-loops=1 -march=i386'
$GCC -c $GCCFLAGS -ansi -pedantic -W -Wall -Werror=implicit-function-declaration -o test1gc.o test1.c
$GCC -c $GCCFLAGS -ansi -pedantic -W -Wall -Werror=implicit-function-declaration -Wno-long-long -o test2gc.o test2.c
# Do the linking separately, because gcc passes too many harmful flags to
# `ld' (especially without the recent `gcc -fno-use-linker-plugin').
LD="$($GCC -print-prog-name=ld)"
test "$LD"
"$LD" -m elf_i386 -o test1gc test1gc.o minilibc32.o
"$LD" -m elf_i386 -o test2gc test2gc.o minilibc32f.o
"$LD" -m elf_i386 -o test2gca test2gc.o minilibc32a.o

# Compile program test_hello.ow with OpenWatcom (owcc).
owcc -blinux -fnostdlib -o test_hello.ow -Os -s -fno-stack-check -march=i386 -W -Wall -Wextra -Werror test_hello.c minilibc32we.obj && $SSTRIP test_hello.ow

# Manual tests:
# $ ./test2ow 1234567890123456789 9876543210
# 8626543209
# $ ./test2gc 1234567890123456789 9876543210
# 8626543209

: "$O" OK.
