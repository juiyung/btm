#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "util.h"

const char *progname;

void
vwarn(const char *fmt, va_list ap)
{
	int e = 0;
	char c = '\0';

	if (fmt[0]) {
		c = fmt[strlen(fmt) - 1];
		if (c == ':')
			e = errno;
	}
	if (progname)
		fprintf(stderr, "%s: ", progname);
	vfprintf(stderr, fmt, ap);
	if (c == ':')
		fprintf(stderr, " %s", strerror(e));
	fputc('\n', stderr);
}

void
warn(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	vwarn(fmt, ap);
	va_end(ap);
}

void
die(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	vwarn(fmt, ap);
	va_end(ap);
	exit(1);
}

int
xatoi(const char *str)
{
	int i;
	long l;
	char *ep;

	errno = 0;
	i = l = strtol(str, &ep, 0);
	if (errno)
		die("strtol %s:", str);
	if (i != l)
		die("%ld unrepresentable as int", l);
	ep += strspn(ep, " \t");
	if (*ep)
		die("%s: Trailing characters: `%s'", str, ep);
	return i;
}

long long
xatoll(const char *str)
{
	long long ll;
	char *ep;

	errno = 0;
	ll = strtoll(str, &ep, 0);
	if (errno)
		die("strtoll %s:", str);
	ep += strspn(ep, " \t");
	if (*ep)
		die("%s: Trailing characters: `%s'", str, ep);
	return ll;
}
