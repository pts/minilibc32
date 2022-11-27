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

set -ex

# For size comparisons of the file minilibc32.bin.
$NASM -O9 -f bin -o minilibc32.bin minilibc32.nasm
ls -ld minilibc32.bin

# Compile the libc for OpenWatcom Linux i386.
$NASM -O9 -f obj -o minilibc32.obj minilibc32.nasm
# Compile write(2)+exit(2) version (for hello-world benchmark).
$NASM -O9 -f obj -DFEATURES_WE -o minilibc32we.obj minilibc32.nasm

# Compile program test1ow with OpenWatcom (owcc).
owcc -blinux -fnostdlib -o test1ow -Os -s -fno-stack-check -march=i386 -W -Wall -Wextra -Werror test1.c minilibc32.obj

# Compile program test_hello.ow with OpenWatcom (owcc).
owcc -blinux -fnostdlib -o test_hello.ow -Os -s -fno-stack-check -march=i386 -W -Wall -Wextra -Werror test_hello.c minilibc32we.obj && $SSTRIP test_hello.ow

: "$O" OK.
