#include "libc.h"

int main(int argc, char **argv) {
  (void)argc;
  (void)argv;
  write(STDOUT_FILENO, argv[0], strlen(argv[0]));
  write(STDOUT_FILENO, argv[1] && isxdigit(argv[1][0]) ? "#" : "-", 1);
  write(STDOUT_FILENO, "Hello, World!\n", 14);
  close(creat("afile", 0644));
  if (remove("bfile") == -1) argc = 77;
  rename("afile", "afile.new");
  return argc;
}
