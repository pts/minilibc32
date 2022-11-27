#include "libc.h"

int main(int argc, char **argv) {
  static const char msg[] = "Hello, World!\n";
  (void)argc; (void)argv;
  write(STDOUT_FILENO, msg, sizeof(msg) - 1);  /* Omit trailing NUL. */
  return 0;
}
