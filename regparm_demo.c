/*
 * regparm_demo.c: demonstrates Linux i386 `gcc -mregparm=3' calling convention.
 * by pts@fazekas.hu at Sat Nov 26 15:30:27 CET 2022
 *
 * gcc -m32 -march=i386 -fno-pic -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -S -Os regparm_demo.c && cat regparm_demo.s
 */

/* a1:eax, a2:edx, a3:ecx, result:eax; ecx and edx are used as scratch. */
__attribute__((regparm(3))) int func3(int a1, int a2, int a3) {
  return a1 + (a2 ^ 2) + (a3 ^ 3);
}

/* No registers passed on stack: warning: argument to ‘regparm’ attribute larger than 3 */
__attribute__((regparm(4))) int func4a(int a1, int a2, int a3, int a4) {
  return a1 + (a2 ^ 2) + (a3 ^ 3) + (a4 ^ 4);
}

/* a1:eax, a2:edx, a3:ecx, a4:[esp+4] result:eax; ecx and edx are used as scratch. */
__attribute__((regparm(3))) int func4b(int a1, int a2, int a3, int a4) {
  return a1 + (a2 ^ 2) + (a3 ^ 3) + (a4 ^ 4);
}

/* a1:eax, a2:edx, a3:ecx, a4:[esp+4], a5:[esp+8], result:eax; ecx and edx are used as scratch. */
__attribute__((regparm(3))) int func5(int a1, int a2, int a3, int a4, int a5) {
  return a1 + (a2 ^ 2) + (a3 ^ 3) + (a4 ^ 4) + (a5 ^ 5);
}

void regsave(void) {
  /* Fake assembly code that ruins all the registers. */
  /* EAX, ECX and EDX are scratch registers for the called functions.
   * gcc generates code to push/pop EBX, EDI, ESI and EBP.
   */
  __asm__ __volatile__ ("" : : : "eax", "ebx", "ecx", "edi", "esi", "edi", "ebp", "memory");
}
