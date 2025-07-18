#define _POSIX_C_SOURCE 200809L /* for getopt() and getline() */
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "btm.h"
#include "util.h"

static long long nstep = 50;
static long long start = 0;
static int sflag = 0, cflag = 0;
static BTM *btm;

static void
usage(void)
{
	printf(
"usage: %s [options] [btm-spec]...\n"
"options:\n"
"  -s        only summarize the emulation\n"
"  -c        for every BTM that didn't finish, append to its summary a colon\n"
"            followed by the BTM's specs after the last step\n"
"  -n nstep  if NSTEP is positive, it sets the maximum number of steps,\n"
"            otherwise there is no limit. the default is 50\n"
"  -b start  START indicates the number of steps the BTMs have already run\n"
"  -h        show this help message and exit\n"
"BTM specs are read from stdin if none is given in the command line\n"
	, progname);
}

static void
putconf(BTM *btm)
{
	int i, j, k, h;

	btm_get_range(btm, &i, &j);
	h = btm_get_head(btm);
	if (h < i)
		i = h;
	else if (h >= j)
		j = h + 1;
	for (k = i; k < j; ++k) {
		putchar(btm_get_cell(btm, k));
		if (k == h)
			printf("(%d)", btm_get_state(btm));
	}
	putchar('\n');
}

static void
handle(char *str)
{
	char *conf, *p, *q;
	long long n;

	if ((conf = strchr(str, ',')))
		*conf++ = '\0';
	if (btm_table_load(btm, str)) {
		warn("btm_table_load %s:", str);
		return;
	}
	btm_reset(btm);
	if (conf) {
		p = conf + strspn(conf, " \t");
		n = strspn(p, "01");
		if (btm_set_tape(btm, -n + 1, 1, p))
			die("btm_set_tape:");
		p += n;
		p += strspn(p, " \t");
		if (*p != '(' || !(q = strchr(p + 1, ')')))
			die("%s: Invalid configuration", conf);
		*q = '\0';
		if (btm_set_state(btm, xatoi(p + 1)))
			die("btm_set_state:");
		*q++ = ')';
		p = q + strspn(q, " \t");
		if ((n = strspn(p, "01"))) {
			if (btm_set_tape(btm, 1, n + 1, p))
				die("btm_set_tape:");
			p += n;
			p += strspn(p, " \t");
		}
		if (*p)
			die("%s: Trailing characters: `%s'", conf, p);
	}
	if (sflag) {
		n = btm_run(btm, nstep, NULL);
		if (n < 0)
			die("btm_run:");
	} else {
		printf("%s:\n", str);
		for (n = 0; n < nstep && btm_get_state(btm) >= 0; ++n) {
			printf("%lld: ", start + n);
			putconf(btm);
			if (btm_run(btm, 1, NULL) < 0)
				die("btm_run:");
		}
	}
	if (btm_get_state(btm) < 0) {
		printf("%s finished in %lld steps\n", str, start + n);
	} else {
		printf("%s continues after %lld steps", str, start + n);
		if (cflag) {
			printf(": %s,", str);
			putconf(btm);
		} else {
			putchar('\n');
		}
	}
	fflush(stdout);
}

int
main(int argc, char **argv)
{
	int c;
	int i;
	char *p;
	size_t l;
	ssize_t n;

	progname = argv[0];
	while ((c = getopt(argc, argv, ":csb:n:h")) != -1) {
		switch (c) {
		case 'c':
			cflag = 1;
			break;
		case 's':
			sflag = 1;
			break;
		case 'b':
			start = xatoll(optarg);
			break;
		case 'n':
			nstep = xatoll(optarg);
			if (nstep <= 0)
				nstep = LLONG_MAX;
			break;
		case 'h':
			usage();
			return 0;
		case ':':
			die("Option -%c requires an operand", optopt);
		default:
			die("Unrecognized option: -%c", optopt);
		}
	}
	if (!(btm = btm_new()))
		die("btm_new:");
	if (optind == argc || !strcmp(argv[optind], "-")) {
		p = NULL;
		for (i = 0; (n = getline(&p, &l, stdin)) != -1; ++i) {
			if (p[n - 1] == '\n')
				p[n - 1] = '\0';
			if (!p[strspn(p, " \t")]) {
				--i;
				continue;
			}
			if (!sflag && i)
				putchar('\n');
			handle(p);
		}
		if (ferror(stdin))
			die("getline:");
		free(p);
	} else {
		for (i = optind; i < argc; ++i) {
			if (!sflag && i > optind)
				putchar('\n');
			handle(argv[i]);
		}
	}
	btm_del(btm);
	return 0;
}
