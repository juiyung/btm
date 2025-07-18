#define _POSIX_C_SOURCE 200809L /* for getopt() and sigaction() */
#define _DEFAULT_SOURCE /* for setlinebuf() */
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "btm.h"
#include "util.h"

static sig_atomic_t done = 0;
static int size = -1;
static int len = -1;
static int flags = 0;
static int maxout = -1;
static int aflag = 0, mflag = 0, sflag = 0;
static char *prefix = NULL;
static long long minrun = 0, maxrun = 0;
static int maxtry = -1;
static int zindex = 0;
static int minrep = 0;
static int duplen = 0;

static char *mark;
static int *steps;

static void
usage(void)
{
	printf(
"usage: %s [options] size\n"
"options:\n"
"  -c         generate only cyclic BTMs\n"
"  -e         generate only non-erasing BTMs\n"
"  -f         generate only BTMs with at least one FIN\n"
"  -u         avoid BTMs with multiple FINs\n"
"  -m         avoid mirrored BTMs\n"
"  -a         if a maximum number of steps is specified with option -t, append\n"
"             to each BTM a tab and the number of steps it can run\n"
"  -s         exclude separable BTMs\n"
"  -l length  generate LENGTH long BTM prefixes instead of BTMs\n"
"  -n maxout  output only MAXOUT results\n"
"  -p prefix  generate only BTMs prefixed by PREFIX\n"
"  -r maxtry  if MAXTRY is non-negative, randomly try MAXTRY BTMs, otherwise\n"
"             randomly generate indefinitely\n"
"  -t minrun[,maxrun]\n"
"             output only BTMs that can run at least MINRUN steps and, if MAXOUT\n"
"             is specified, at most MAXRUN steps\n"
"  -z minrep,index\n"
"             exclude BTMs whose invoked instructions repeat MINREP times in the\n"
"             N*2 steps after the first N steps, where N is any of MINREP,\n"
"             MINREP*2, ..., MINREP*2^(INDEX-1)\n"
"  -d duplen  take all steps recorded by the use of option -z, deduplicate\n"
"             sequences that are at most DUPLEN long and redo repetition\n"
"             detection in the last 2/3 portion\n"
"  -h         show this help message and exit\n"
	, progname);
}

static void
setdone(int sig)
{
	done = 1;
}

static int
separable(const BTM *btm)
{
	int q, n, i, j;
	int changed;
	int marked;

	n = btm_get_size(btm);
	memset(mark, 0, n);
	marked = 0;
	if (flags & BTM_EXCL_NO_FIN) {
		mark[0] = 1;
		++marked;
	}
	for (q = n - 1; q; --q) {
		if ((i = BTM_INSTR_Q(btm_get_instr(btm, q, '0'))) < 0 || mark[i]
		 || (j = BTM_INSTR_Q(btm_get_instr(btm, q, '1'))) < 0 || mark[j]) {
			mark[q] = 1;
			++marked;
		} else if (i == q && j == q) {
			return 1;
		}
	}
	do {
		changed = 0;
		for (q = n - 1; q; --q) {
			if (mark[q])
				continue;
			if (mark[BTM_INSTR_Q(btm_get_instr(btm, q, '0'))]
			 || mark[BTM_INSTR_Q(btm_get_instr(btm, q, '1'))]) {
				mark[q] = 1;
				++changed;
			}
		}
	} while (changed && (marked += changed) < n);
	return marked < n;
}

static int
repeating(const int *a, int n)
{
	int instr;
	int p, q, m, i, j;

	q = n / minrep;
	instr = a[0];
	for (p = 1; p <= q; ++p) {
		for (i = p; i < n; i += p)
			if (a[i] != instr)
				goto nextp;
		for (i = p; i < n; i += p) {
			m = MIN(p, n - i);
			for (j = 1; j < m; ++j)
				if (a[j] != a[i + j])
					goto nextp;
		}
		return 1;
nextp:;
	}
	return 0;
}

static void
dedup(int *a, int *n)
{
	int i, j, k, m, p;

	for (i = 0; i < *n - 1; ++i) {
		m = MIN(duplen, *n - i);
		for (p = 1; p <= m; ++p) {
			j = i + p;
			for (k = 0; k < p && a[i + k] == a[j + k]; ++k)
				;
			if (k == p)
				break;
		}
		if (p > m)
			continue;
		j = i + p * 2;
		for (k = p; k; --k)
			a[j - k] = BTM_FIN;
		while (j < *n) {
			for (k = 0; k < p && a[i + k] == a[j + k]; ++k)
				;
			if (k < p)
				break;
			while (k--)
				a[j++] = BTM_FIN;
		}
		i = j - 1;
	}
	for (i = j = 1;;) {
		while (j < *n && a[j] == BTM_FIN)
			++j;
		if (j == *n)
			break;
		a[i++] = a[j++];
	}
	*n = i;
}

static int
btmok(BTM *btm, long long *nstep)
{
	int i, n, t;

	if (sflag && separable(btm))
		return 0;
	btm_reset(btm);
	*nstep = 0;
	if (minrep > 1) {
		for (i = 1; i < zindex && 1 << i < minrep; ++i)
			;
		n = 1 << (i - 1);
		*nstep += btm_run(btm, n * 3, steps);
		for (;; n = 1 << i++) {
			if (btm_get_state(btm) < 0)
				break;
			if (repeating(steps + n, n * 2))
				return 0;
			if (i == zindex || (maxrun && *nstep + n * 3 > maxrun))
				break;
			*nstep += btm_run(btm, n * 3, steps + n * 3);
		}
		if (i == zindex && duplen > 0) {
			t = n * 3;
			*nstep += btm_run(btm, duplen, steps + t);
			if (btm_get_state(btm) >= 0) {
				dedup(steps, &t);
				if (repeating(steps + t / 3, t - t / 3))
					return 0;
			}
		}
	}
	if (minrun && *nstep < minrun) {
		*nstep += btm_run(btm, minrun - *nstep, NULL);
		if (*nstep < minrun)
			return 0;
	}
	if (maxrun) {
		if (*nstep > maxrun)
			return 0;
		*nstep += btm_run(btm, maxrun - *nstep, NULL);
		if (*nstep == maxrun && btm_get_state(btm) >= 0)
			return 0;
	}
	return 1;
}

static void
enumerate(const char *prefix)
{
	BTMIter *it;
	BTM *btm;
	long long nstep;
	char *str;
	int instr;

	if (!(it = btm_iter_new(size, flags, prefix, len)))
		die("btm_iter_new:");
	for (; !done && maxout && (btm = btm_iter_deref(it)); btm_iter_incr(it)) {
		if ((flags & BTM_RANDOM) && !maxtry--)
			break;
		if (!prefix && mflag) {
			instr = btm_get_instr(btm, 0, '0');
			if (instr != BTM_FIN && BTM_INSTR_M(instr) == 'L')
				btm_set_instr(btm, 0, '0', BTM_INSTR(BTM_INSTR_Q(instr), BTM_INSTR_S(instr), 'R'));
		}
		if (!btmok(btm, &nstep))
			continue;
		if (!(str = btm_table_dump(btm)))
			die("btm_table_dump:");
		if (len >= 0)
			(str + strlen(str))[len - size * 2] = '\0';
		if (aflag)
			printf("%s\t%lld\n", str, nstep);
		else
			puts(str);
		free(str);
		--maxout;
	}
	btm_iter_del(it);
}

int
main(int argc, char **argv)
{
	int c, n;
	char *p;
	struct sigaction sa;

	progname = argv[0];
	while ((c = getopt(argc, argv, ":cefuamsd:l:n:p:r:t:z:h")) != -1) {
		switch (c) {
		case 'c': flags |= BTM_CYCLIC; break;
		case 'e': flags |= BTM_NONERASING; break;
		case 'f': flags |= BTM_EXCL_NO_FIN; break;
		case 'u': flags |= BTM_EXCL_MULTI_FIN; break;
		case 'a': aflag = 1; break;
		case 'm': mflag = 1; break;
		case 's': sflag = 1; break;
		case 'd':
			duplen = xatoi(optarg);
			break;
		case 'l':
			len = xatoi(optarg);
			break;
		case 'n':
			maxout = xatoi(optarg);
			break;
		case 'p':
			prefix = optarg;
			break;
		case 'r':
			maxtry = xatoi(optarg);
			flags |= BTM_RANDOM;
			break;
		case 't':
			if ((p = strchr(optarg, ',')))
				*p++ = '\0';
			minrun = xatoll(optarg);
			if (minrun < 0)
				minrun = 0;
			if (p) {
				maxrun = xatoll(p);
				if (maxrun < minrun)
					maxrun = 0;
			}
			break;
		case 'z':
			if ((p = strchr(optarg, ',')))
				*p++ = '\0';
			minrep = xatoi(optarg);
			if (minrep <= 0)
				break;
			if (!p)
				die("Option -z requires two values");
			zindex = xatoi(p);
			break;
		case 'h':
			usage();
			return 0;
		case ':':
			die("Option -%c requires operand", optopt);
		default:
			die("Unrecognized option: -%c", optopt);
		}
	}
	if (len >= 0) {
		aflag = sflag = zindex = 0;
		minrun = maxrun = minrep = maxtry = 0;
	}
	if (argc - optind > 1)
		die("Too many arguments");
	if (len < 0 && argc == optind)
		die("Missing argument");
	if (argc > optind)
		size = xatoi(argv[optind]);
	if (len >= 0 && size < 0)
		size = len + 1;
	len = MIN(len, size * 2);
	if (!maxrun)
		aflag = 0;
	if (flags & BTM_CYCLIC)
		sflag = 0;
	if (!(mark = malloc(size)))
		die("malloc:");
	if (minrep > 1) {
		n = 1 << (zindex - 1);
		if (!(steps = malloc((n * 3 + duplen) * sizeof(*steps))))
			die("malloc:");
	}
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = 0;
	sa.sa_handler = setdone;
	if (sigaction(SIGTERM, &sa, NULL)
	|| sigaction(SIGINT, &sa, NULL))
		die("sigaction:");
	setlinebuf(stdout);
	if (prefix && prefix[strspn(prefix, " \t")]) {
		enumerate(prefix);
	} else if (flags & BTM_RANDOM) {
		enumerate(NULL);
	} else {
		if (minrun <= 1)
			enumerate("f");
		if (size > 1 && !maxrun && minrep < 1 && !(flags & BTM_CYCLIC)) {
			if (!mflag) {
				enumerate("o0");
				enumerate("i0");
			}
			enumerate("O0");
			enumerate("I0");
		}
		if (!mflag) {
			enumerate("o");
			enumerate("i");
		}
		enumerate("O");
		enumerate("I");
	}
	free(steps);
	free(mark);
	return 0;
}
