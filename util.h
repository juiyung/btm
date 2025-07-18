#ifndef UTIL_H_
#define UTIL_H_

#define MAX(A, B) ((A) > (B) ? (A) : (B))
#define MIN(A, B) ((A) < (B) ? (A) : (B))

#ifdef va_arg
void vwarn(const char *fmt, va_list ap);
#endif
void warn(const char *fmt, ...);
void die(const char *fmt, ...);
int xatoi(const char *str);
long long xatoll(const char *str);

extern const char *progname;

#endif
