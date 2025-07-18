#include <errno.h>
#include <fcntl.h> /* for open() */
#include <stdio.h> /* for snprintf() */
#include <stdlib.h>
#include <string.h>
#include <unistd.h> /* for close() */

#include "btm.h"

#define INIT_TABLE_SZ  8
#define INIT_TAPE_SZ   65
#define MIN(A, B)      ((A) < (B) ? (A) : (B))
#define MAX(A, B)      ((A) > (B) ? (A) : (B))
#define SMASK          2
#define MMASK          1

struct btm {
	int (*table)[2];
	char *tape;
	char *head;
	int size;
	int tablesize;
	int tapesize;
	int tapebase;
	int tapestart;
	int tapeend;
	int state;
};

struct btm_iter {
	BTM *btm;
	int *top;
	int flags;
	int len;
	int prefixlen;
};

static int str2instr(const char *p, char **ep);
static int prefixok(BTMIter *it);
static int reservetable(BTM *btm, int size);
static int reservetape(BTM *btm, int start, int end);
static int findfin(const int *table, int end);
static void filltable(BTMIter *it, int start);

int
str2instr(const char *p, char **ep)
{
	int instr;
	long l;

	p += strspn(p, " \t");
	switch (*p++) {
	case 'o': instr = 0; break;
	case 'O': instr = MMASK; break;
	case 'i': instr = SMASK; break;
	case 'I': instr = SMASK|MMASK; break;
	case 'f':
		*ep = (char *)p;
		return BTM_FIN;
	default:
		errno = EINVAL;
		return -1;
	}
	p += strspn(p, " \t");
	if (!*p || strchr("iIoOf", *p)) {
		instr -= 8;
		*ep = (char *)p;
	} else {
		errno = 0;
		l = strtol(p, ep, 0);
		if (l < 0) {
			errno = EINVAL;
			return -1;
		}
		instr |= l << 2;
		if (!errno && instr >> 2 != l)
			errno = ERANGE;
		if (errno)
			return -1;
	}
	return instr;
}

int
prefixok(BTMIter *it)
{
	const int *const table = (int *)it->btm->table;
	const int size = it->btm->size;
	const int flags = it->flags;
	const int prefixlen = it->prefixlen;
	int i, n, nfin;

	if (!prefixlen)
		return 1;
	n = 1;
	for (i = 0; i < prefixlen; ++i) {
		if (i >> 1 >= n || table[i] >> 2 > MIN(n, size - 1))
			return 0;
		if (table[i] >> 2 == n)
			++n;
	}
	i = prefixlen - 1;
	if ((i & 1) && n == (i >> 1) + 1 && n < size && table[i - 1] >> 2 < n && table[i] >> 2 < n)
		return 0;
	nfin = 0;
	for (i = 0; i < prefixlen; ++i) {
		if (table[i] == BTM_FIN) {
			if ((flags & BTM_EXCL_MULTI_FIN) && nfin)
				return 0;
			++nfin;
			continue;
		}
		if ((flags & BTM_NONERASING) && (i & 1) && !(table[i] & SMASK))
			return 0;
		if ((flags & BTM_CYCLIC) && table[i] >> 2 != ((i >> 1) + 1) % size)
			return 0;
	}
	if ((flags & BTM_EXCL_NO_FIN) && prefixlen == size * 2 && !nfin)
		return 0;
	return 1;
}

int
reservetable(BTM *btm, int size)
{
	int newtablesize;
	int (*newtable)[2];
	int i;

	if (btm->tablesize >= size)
		return 0;
	newtablesize = MAX(size, btm->tablesize * 3 >> 1);
	if (!(newtable = realloc(btm->table, newtablesize * sizeof(*newtable))))
		return -1;
	for (i = btm->tablesize; i < newtablesize; ++i)
		newtable[i][0] = newtable[i][1] = BTM_FIN;
	btm->table = newtable;
	btm->tablesize = newtablesize;
	return 0;
}

int
reservetape(BTM *btm, int start, int end)
{
	int newtapesize, newtapebase;
	char *newtape;
	int h, i, j;

	if (start >= -btm->tapebase && end <= btm->tapesize - btm->tapebase)
		return 0;
	start = MIN(start, -btm->tapebase);
	end = MAX(end, btm->tapesize - btm->tapebase);
	h = btm_get_head(btm);
	btm_get_range(btm, &i, &j);
	newtapesize = end - start;
	newtapebase = -start;
	if (!(newtape = realloc(btm->tape, newtapesize)))
		return -1;
	btm->tape = newtape;
	if (newtapebase > btm->tapebase) {
		memmove(newtape + newtapebase + i, newtape + btm->tapebase + i, j - i);
		memset(newtape + btm->tapebase + i, 0, newtapebase - btm->tapebase);
	}
	memset(newtape + newtapebase + j, 0, newtapesize - newtapebase - j);
	btm->tapebase = newtapebase;
	btm->tapesize = newtapesize;
	btm->head = newtape + btm->tapebase + h;
	return 0;
}

int
findfin(const int *table, int end)
{
	int i;

	for (i = 0; i < end; ++i)
		if (table[i] == BTM_FIN)
			return i;
	return -1;
}

void
filltable(BTMIter *it, int start)
{
	int *const table = (int *)it->btm->table;
	const int size = it->btm->size;
	int *const top = it->top;
	const int flags = it->flags;
	int hadfin;
	int i, q, r, n;

	if (start >= it->len)
		return;
	start = MAX(start, it->prefixlen);
	hadfin = findfin(table, start) >= 0;
	q = start >> 1;
	if (start & 1) {
		n = top[q];
		n += (table[start - 1] >> 2 == n);
	} else if (q) {
		n = top[q - 1];
		n += (table[start - 2] >> 2 == n);
		n += (table[start - 1] >> 2 == n);
	} else {
		n = 1;
	}
	for (i = start; i < it->len; ++i) {
		q = i >> 1;
		if (!(i & 1))
			top[q] = n;
		if ((i & 1) && n == q + 1 && n < size) {
			table[i] = n << 2;
			if (flags & BTM_RANDOM)
				table[i] |= rand() & 3;
			if (flags & BTM_NONERASING)
				table[i] |= SMASK;
			++n;
			continue;
		}
		if ((!(flags & BTM_EXCL_MULTI_FIN) || !hadfin) && (!(flags & BTM_RANDOM)
		|| !((flags & BTM_EXCL_NO_FIN) && !hadfin ? rand() % (size * 2 - i) : rand() % (size * 2)))) {
			table[i] = BTM_FIN;
			hadfin = 1;
			continue;
		}
		table[i] = 0;
		if (flags & BTM_RANDOM) {
			r = rand();
			table[i] = r & 3;
			r >>= 2;
		}
		if (flags & BTM_CYCLIC)
			table[i] |= ((q + 1) % size) << 2;
		else if (flags & BTM_RANDOM)
			table[i] |= r % MIN(n + 1, size) << 2;
		if (table[i] >> 2 == n)
			++n;
		if ((i & 1) && (flags & BTM_NONERASING) && table[i] != BTM_FIN)
			table[i] |= SMASK;
	}
}

BTM *
btm_new(void)
{
	BTM *btm;
	int i;

	if (!(btm = calloc(1, sizeof(*btm)))
	|| !(btm->table = malloc((btm->tablesize = INIT_TABLE_SZ) * sizeof(*btm->table)))
	|| !(btm->tape = calloc(btm->tapesize = INIT_TAPE_SZ, 1))) {
		btm_del(btm);
		return NULL;
	}
	for (i = 0; i < btm->tablesize; ++i)
		btm->table[i][0] = btm->table[i][1] = BTM_FIN;
	btm->tapebase = (btm->tapesize + 1) / 2;
	btm->head = btm->tape + btm->tapebase;
	return btm;
}

void
btm_del(BTM *btm)
{
	if (!btm)
		return;
	free(btm->table);
	free(btm->tape);
	free(btm);
}

int
btm_set_state(BTM *btm, int q)
{
	if (q >= btm->size) {
		errno = EINVAL;
		return -1;
	}
	btm->state = q;
	return 0;
}

int
btm_set_head(BTM *btm, int h)
{
	int i, j;

	btm_get_range(btm, &i, &j);
	if (h < i) {
		if (reservetape(btm, h, j))
			return -1;
		if (h < i - 1)
			memset(btm->tape + btm->tapebase + h + 1, '0', i - h - 1);
	} else if (h >= j) {
		if (reservetape(btm, i, h + 1))
			return -1;
		if (h > j)
			memset(btm->tape + btm->tapebase + j, '0', h - j);
	}
	btm->head = btm->tape + btm->tapebase + h;
	return 0;
}

int
btm_set_instr(BTM *btm, int q, char s, int instr)
{
	int maxq, r, i;

	if (q < 0 || (s != '0' && s != '1') || (instr != BTM_FIN && instr >> 2 < 0)) {
		errno = EINVAL;
		return -1;
	}
	maxq = MAX(instr >> 2, q);
	if (btm->size <= maxq) {
		if (reservetable(btm, maxq + 1))
			return -1;
		btm->size = maxq + 1;
	}
	r = btm->table[q][s == '1'] >> 2;
	btm->table[q][s == '1'] = instr;
	if (r == btm->size - 1 && instr >> 2 < r) {
		maxq = -1;
		for (r = 0; r < btm->size; ++r) {
			for (i = 0; i < 2; ++i) {
				maxq = MAX(maxq, btm->table[r][i] >> 2);
				if (btm->table[r][i] >> 2 == btm->size - 1)
					break;
			}
		}
		btm->size = maxq + 1;
	}
	return 0;
}

int
btm_set_tape(BTM *btm, int start, int end, const char *tape) 
{
	if (start > end || !tape) {
		errno = EINVAL;
		return -1;
	}
	if (reservetape(btm, start, end))
		return -1;
	memcpy(btm->tape + btm->tapebase + start, tape, end - start);
	return 0;
}

long long
btm_run(BTM *btm, long long nstep, int *steps)
{
	long long n;
	int h, m, t;
	int instr;

	if (nstep < 0) {
		errno = EINVAL;
		return -1;
	}
	if (btm->state < 0 || !nstep)
		return 0;
	for (n = 0; n < nstep;) {
		m = btm->tapesize >> 1;
		h = btm_get_head(btm);
		t = MIN(btm->tapebase + h, btm->tapesize - btm->tapebase - h - 1);
		if (m >> 1 <= t) {
			m = MIN(t, nstep - n);
		} else {
			if (m > (nstep - n) >> 1)
				m = nstep - n;
			if (reservetape(btm, h - m, h + m + 1))
				return -1;
		}
		for (; m--; ++n) {
			instr = btm->table[btm->state][*btm->head == '1'];
			btm->state = instr >> 2;
			if (steps)
				steps[n] = instr;
			if (instr == BTM_FIN)
				return ++n;
			*btm->head = BTM_INSTR_S(instr);
			btm->head += instr & MMASK ? 1 : -1;
		}
	}
	return n;
}

void
btm_reset(BTM *btm)
{
	int i, j;

	btm_get_range(btm, &i, &j);
	memset(btm->tape + btm->tapebase + i, 0, j - i);
	btm->head = btm->tape + btm->tapebase;
	btm->tapestart = btm->tapeend = btm->state = 0;
}

int
btm_get_size(const BTM *btm)
{
	return btm->size;
}

int
btm_get_state(const BTM *btm)
{
	return btm->state;
}

int
btm_get_head(const BTM *btm)
{
	return btm->head - btm->tape - btm->tapebase;
}

int
btm_get_instr(const BTM *btm, int q, char s)
{
	if (q < 0 || q >= btm->size || (s != '0' && s != '1')) {
		errno = EINVAL;
		return BTM_FIN - 1;
	}
	return btm->table[q][s == '1'];
}

char
btm_get_cell(const BTM *btm, int i)
{
	char c;

	if (i < 0 ? i < -btm->tapebase : btm->tapebase + i >= btm->tapesize)
		return '0';
	c = btm->tape[btm->tapebase + i];
	return c ? c : '0';
}

char *
btm_get_tape(const BTM *btm, int start, int end)
{
	char *tape;
	int i, j, k, n;

	if (start > end) {
		errno = EINVAL;
		return NULL;
	}
	if (!(tape = malloc(end - start + 1)))
		return NULL;
	btm_get_range(btm, &i, &j);
	if (end <= i || start >= j) {
		memset(tape, '0', end - start);
		tape[end - start] = '\0';
		return tape;
	}
	if (start < i) {
		n = i - start;
		memset(tape, '0', n);
		k = i;
	} else {
		n = 0;
		k = start;
	}
	memcpy(tape + n, btm->tape + btm->tapebase + k, j < end ? j - k : end - k);
	if (j < end)
		memset(tape + n + j - k, '0', end - j);
	tape[end - start] = '\0';
	return tape;
}

void
btm_get_range(const BTM *btm, int *start, int *end)
{
	int i;

	if (start) {
		for (i = btm->tapebase + btm->tapestart; i > 0 && btm->tape[i - 1]; --i)
			;
		*start = ((BTM *)btm)->tapestart = i - btm->tapebase;
	}
	if (end) {
		for (i = btm->tapebase + btm->tapeend; i < btm->tapesize && btm->tape[i]; ++i)
			;
		*end = ((BTM *)btm)->tapeend = i - btm->tapebase;
	}
}

int
btm_table_load(BTM *btm, const char *str)
{
	int *table;
	int i, q, maxq;
	const char *p;
	int instr;

	maxq = -1;
	p = str + strspn(str, " \t");
	for (i = 0; *p; ++i) {
		if (!(i & 1) && reservetable(btm, (i >> 1) + 1)) {
			btm_del(btm);
			return -1;
		}
		instr = str2instr(p, (char **)&p);
		if (instr == -1)
			goto invalid;
		p += strspn(p, " \t");
		q = instr >> 2;
		if (q == -2) {
			q = (i >> 1) + 1;
			instr = q << 2 | (instr & 3);
		} else {
			maxq = MAX(maxq, q);
		}
		btm->table[i >> 1][i & 1] = instr;
	}
	btm->size = i >> 1;
	if (!i || (i & 1) || maxq >= btm->size)
		goto invalid;
	table = (int *)btm->table;
	if (table[i - 1] >> 2 == btm->size)
		table[i - 1] &= 3;
	if (table[i - 2] >> 2 == btm->size)
		table[i - 2] &= 3;
	btm->size = i >> 1;
	return 0;
invalid:
	errno = EINVAL;
	return -1;
}

char *
btm_table_dump(const BTM *btm)
{
	char *str, *p;
	int i, l;
	int instr;

	if (!btm->size)
		return NULL;
	for (i = btm->size, l = 0; i; i /= 10, ++l)
		;
	if (!(str = malloc(btm->size * (l + 1) * 2 + 1)))
		return NULL;
	p = str;
	for (i = 0; i < btm->size * 2; ++i) {
		instr = btm->table[i >> 1][i & 1];
		if (instr == BTM_FIN) {
			*p++ = 'f';
			continue;
		}
		switch (instr & 3) {
		case 0: *p++ = 'o'; break;
		case MMASK: *p++ = 'O'; break;
		case SMASK: *p++ = 'i'; break;
		case MMASK|SMASK: *p++ = 'I'; break;
		}
		if (instr >> 2 != ((i >> 1) + 1) % btm->size)
			p += snprintf(p, l + 1, "%d", instr >> 2);
	}
	*p++ = '\0';
	if (!(str = realloc(p = str, strlen(str) + 1))) {
		free(p);
		errno = ENOMEM;
		return NULL;
	}
	return str;
}

BTMIter *
btm_iter_new(int size, int flags, const char *prefix, int len)
{
	BTMIter *it;
	const char *p;
	int q, i, n;
	int instr;

	if (size < 0) {
		errno = EINVAL;
		return NULL;
	}
	if (flags & BTM_RANDOM) {
		if ((n = open("/dev/urandom", O_RDONLY)) < 0)
			return NULL;
		if (read(n, &i, sizeof(i)) != sizeof(i)) {
			close(n);
			return NULL;
		}
		close(n);
		srand(i);
	}
	if (!(it = calloc(1, sizeof(*it))))
		return NULL;
	it->flags = flags;
	if (!size)
		return it;
	if (!(it->btm = btm_new())
	|| !(it->top = calloc(size, sizeof(*it->top)))
	|| reservetable(it->btm, size)) {
		btm_iter_del(it);
		errno = ENOMEM;
		return NULL;
	}
	it->btm->size = size;
	if (prefix) {
		p = prefix;
		for (i = 0; *(p += strspn(p, " \t")); ++i) {
			if (i >> 1 == it->btm->tablesize)
				goto invalid;
			instr = str2instr(p, (char **)&p);
			if (instr == -1)
				goto invalid;
			if (instr != BTM_FIN) {
				q = instr >> 2;
				if (q == -2) {
					q = ((i >> 1) + 1) % size;
					instr = q << 2 | (instr & 3);
				}
			}
			it->btm->table[i >> 1][i & 1] = instr;
		}
		it->prefixlen = i;
		if (!prefixok(it))
			goto invalid;
		n = 1;
		for (i = 0; i < it->prefixlen; ++i) {
			q = i >> 1;
			if (!(i & 1))
				it->top[q] = n;
			if (it->btm->table[q][i & 1] >> 2 == n)
				++n;
		}
	}
	it->len = len < it->prefixlen ? size * 2 : len;
	filltable(it, 0);
	return it;
invalid:
	btm_iter_del(it);
	errno = EINVAL;
	return NULL;
}

void
btm_iter_del(BTMIter *it)
{
	if (!it)
		return;
	btm_del(it->btm);
	free(it->top);
	free(it);
}

BTMIter *
btm_iter_incr(BTMIter *it)
{
	int *table;
	int size;
	int flags;
	int i, q, n;

	if (!it->btm)
		return it;
	table = (int *)it->btm->table;
	size = it->btm->size;
	flags = it->flags;
			n += (table[i] == BTM_FIN);
	if (flags & BTM_RANDOM) {
		filltable(it, 0);
		return it;
	}
	i = it->len;
	while (i-- > it->prefixlen) {
		if (table[i] == BTM_FIN)
			continue;
		if ((table[i] & 3) == 3) {
			if ((i & 1) && (flags & BTM_NONERASING))
				table[i] &= ~MMASK;
			else
				table[i] &= ~3;
			continue;
		}
		if ((i & 1) && (flags & BTM_NONERASING))
			table[i] |= MMASK;
		else
			++table[i];
		return it;
	}
	i = it->len;
	if (i == size * 2 && i-- > it->prefixlen) {
		if (table[i] != BTM_FIN) {
			if (!(flags & BTM_CYCLIC) && table[i] >> 2 < size - 1) {
				table[i] += 4;
				return it;
			}
		} else if (!(flags & BTM_EXCL_NO_FIN) || findfin(table, i) >= 0) {
			table[i] = 0;
			if (flags & BTM_NONERASING)
				table[i] |= SMASK;
			return it;
		}
	}
	while (i-- > it->prefixlen) {
		q = i >> 1;
		n = it->top[q];
		if ((i & 1) && table[i - 1] >> 2 == n)
			++n;
		if ((flags & BTM_CYCLIC) || ((i & 1) && n == q + 1 && n < size)) {
			if (table[i] == BTM_FIN) {
				table[i] = (q + 1) % size << 2;
				break;
			}
		} else if (table[i] >> 2 < MIN(n, size - 1)) {
			table[i] += 4;
			break;
		}
	}
	if (i < it->prefixlen) {
		btm_del(it->btm);
		it->btm = NULL;
		free(it->top);
		it->top = NULL;
		return it;
	}
	if ((i & 1) && (flags & BTM_NONERASING))
		table[i] |= SMASK;
	filltable(it, i + 1);
	return it;
}

BTM *
btm_iter_deref(const BTMIter *it)
{
	return it->btm;
}
