/* by pts@fazekas.hu at Thu Dec  1 18:10:55 CET 2022 */

#include <stdio.h>

/* Parse and print command-line arguments (argv) one line at a time.
 *
 * Similar to CommandLineToArgvW(...) in SHELL32.DLL, but doesn't aim for
 * 100% accuracy, especially that it doesn't support non-ASCII characters
 * beyond ANSI well, and that other implementations are also buggy (in
 * different ways).
 *
 * It treats only space and tab as whitespece (like the Wine version of
 * CommandLineToArgvA.c).
 *
 * This is based on the incorrect and incomplete description in:
 *  https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-commandlinetoargvw
 *
 * See https://nullprogram.com/blog/2022/02/18/ for a more detailed writeup
 * and a better installation.
 *
 * https://github.com/futurist/CommandLineToArgvA/blob/master/CommandLineToArgvA.c
 * has the 3*n rule, which Wine 1.6.2 doesn't seem to have. It also has special
 * parsing rules for argv[0] (the program name).
 *
 * There is the CommandLineToArgvW function in SHELL32.DLL available since
 * Windows NT 3.5 (not in Windows NT 3.1). For alternative implementations,
 * see:
 *
 * * https://github.com/futurist/CommandLineToArgvA
 *   (including a copy from Wine sources).
 * * http://alter.org.ua/en/docs/win/args/
 * * http://alter.org.ua/en/docs/win/args_port/
 */
static void print_argv_by_line(const char *p) {
  const char *q;
  char c;
  char is_quote = 0;
  goto ignore_whitespace;
  for (;;) {
    if ((c = *p) == '\0') {
     after_arg:
      putchar('\n');
     ignore_whitespace:
      for (; c = *p, c == ' ' || c == '\t'; ++p) {}
      if (c == '\0') break;
    } else {
      ++p;       
      if (c == '\\') {
        for (q = p; c = *q, c == '\\'; ++q) {}
        if (c == '"') {
          for (; p < q; p += 2) {
            putchar(*p);  /* '\\'. */
          }
          if (p != q) {
            is_quote ^= 1;
          } else {
            putchar(*p);  /* '"'. */
            ++p;  /* Skip over the '"'. */
          }
        } else {
          putchar('\\');  /* '\\'. */
          for (; p != q; ++p) {
            putchar(*p);
          }
        }
      } else if (c == '"') {
        is_quote ^= 1;
      } else if (!is_quote && (c == ' ' || c == '\t')) {
        goto after_arg;
      } else {
        putchar(c);
      }
    }
  }
}

int main(int argc, char **argv) {
  (void)argc;
  print_argv_by_line(argv[1]);  /* Just for debugging. */
  return 0;
}
