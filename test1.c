#include "libc.h"

int main(int argc, char **argv) {
  (void)argc;
  (void)argv;
  if (argv[0][0] != '\0' && strcmp(argv[0], argv[0] + 1) == 0) return 101;  /* Unexpected, these two strings must be different. */
  if (argv[argc] != NULL) return 102;  /* This is also an error: argc--argv inconsistency. */
  write(STDOUT_FILENO, argv[0], strlen(argv[0]));
  write(STDOUT_FILENO, argv[1] && isxdigit(argv[1][0]) ? "#" : "-", 1);
  write(STDOUT_FILENO, "Hello, World!\n", 14);
  close(creat("afile", 0644));
  if (remove("bfile") == -1) argc += 70;
  rename("afile", "afile.new");
  return argc;
}
