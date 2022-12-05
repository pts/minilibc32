/* Test 64-bit integer multiplication, division and modulo.
 *
 * Example test run:
 *
 * $ ./test2... 1234567890123456789 9876543210
 * 8626543209
 */

#include "libc.h"

static long long parse_ll_dec(const char *p) {
  long long result = 0;
  char is_negative = 0;
  if (*p == '-') { is_negative ^= 1; ++p; }
  while (*p + (0U - '0') <= 9U) {
    result = 10 * result + (*p++ - '0');
  }
  return result;
}

static const char *format_ll_dec(long long i) {
  static char buf[sizeof(i) == 8 ? 22 : sizeof(i) * 3 + 2];
  char *p = buf + sizeof(buf) - 1;
  const char is_negative = i < 0;
  unsigned long long u = is_negative ? -i : i;
  *p = '\0';
  do {
    *--p = (char)(u % 10) + '0';
#if 0
    u /= 10;
#else
    *(long long*)&u /= 10;
#endif
  } while (u != 0);
  if (is_negative) *--p = '-';
  return p;
}

#if 0 && defined(__GNUC__)
long long __attribute__((regparm(3))) call__moddi3(long long a, long long b) {
  return __moddi3(a, b);
}
#endif

int main(int argc, char **argv) {
  long long sa, sb;
  unsigned long long ua, ub;
  (void)argc;
  (void)argv;
  sa = ua = (unsigned long long)argv[0][0] << 16;  /* OpenWatcom: __U8LS. GCC: inline */
  sb = ub = (long long)argv[0][1] << 16;  /* OpenWatcom: __I8LS. GCC: inline. */
  sa *= sb;      /* OpenWatcom: __I8M. GCC: inline    */
  sb /= sa;      /* OpenWatcom: __I8D. GCC: __divdi3  */
  sb %= sa + 5;  /* OpenWatcom: __I8D. GCC: __moddi3  */
  ua *= ub;      /* OpenWatcom: __U8M. GCC: inline    */
  ub /= ua;      /* OpenWatcom: __U8D. GCC: __udivdi3 */
  ub %= ua + 5;  /* OpenWatcom: __U8D. GCC: __umoddi3 */
  argv[0][0] = (sa + sb + ua + ub) >> 58;
  if (argv[1] != NULL && argv[2] != NULL) {
    const char *p;
    sa = parse_ll_dec(argv[1]);
    sb = parse_ll_dec(argv[2]);
    sa %= sb;
    p = format_ll_dec(sa);  /* Print dec(argv[1]) % dec(argv[2]). */
    (void)!write(1, p, strlen(p));
    (void)!write(1, "\n", 1);
  }
  return 0;
}
