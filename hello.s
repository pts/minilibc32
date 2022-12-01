/*
 * hello.s: Linux i386 hello-world in simple GNU as (AT&T) syntax
 * by pts@fazekas.hu at Wed Nov 30 05:01:05 CET 2022
 */

.text
.globl _start
_start:
mov $4, %eax
mov $1, %ebx
mov $message, %ecx
/* mov $message_size, %edx */
mov $message_end-message, %edx
int $0x80
xor %eax, %eax
inc %eax
xor %ebx, %ebx
int $0x80
.data
message:
.ascii "Hello, World!\n"
message_end:
/* .set message_size, .-message */
