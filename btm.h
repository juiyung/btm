#ifndef BTM_H_
#define BTM_H_

/*
 * packs a transition target @Q (a state number), a symbol to write @S
 * (character '0' or '1') and a move @M (character 'L' or 'R') into
 * an instruction.
 */
#define BTM_INSTR(Q, S, M) ((Q) << 2 | ((S) == '1') << 1 | ((M) == 'R'))

/*
 * decodes instruction @I:
 *
 * BTM_INSTR_Q - get the transition target
 * BTM_INTTR_S - get the symbol to write
 * BTM_INSTR_M - get the move
 */
#define BTM_INSTR_Q(I)     ((I) >> 2)
#define BTM_INSTR_S(I)     ((I) & 2 ? '1' : '0')
#define BTM_INSTR_M(I)     ((I) & 1 ? 'R' : 'L')

/*
 * the special FIN instruction.
 */
#define BTM_FIN            -4 /* BTM_INSTR(-1, '0', 'L') */

/*
 * flags controlling BTM iterator's behavior:
 *
 * BTM_RANDOM         - perform random iteration
 * BTM_CYCLIC         - iterate only cyclic BTMs
 * BTM_NONERASING     - iterate only non-erasing BTMs
 * BTM_EXCL_NO_FIN    - exclude BTMs without FIN in instruction table 
 * BTM_EXCL_MULTI_FIN - exclude BTMs with more than one FINs in instruction table
 */
#define BTM_RANDOM         1 << 0
#define BTM_CYCLIC         1 << 1
#define BTM_NONERASING     1 << 2
#define BTM_EXCL_NO_FIN    1 << 3
#define BTM_EXCL_MULTI_FIN 1 << 4

/*
 * opaque data type for BTM. a BTM object comprises an instruction table,
 * a tape, a state register and a head.  conceptually, the tape is an
 * array that extends infinitely in both directions, where there is a
 * center cell with index 0, cells to the right have positive indices
 * and cells to the left have negative indices.
 */
typedef struct btm BTM;

/*
 * opaque data type for BTM iterator.
 */
typedef struct btm_iter BTMIter;

/*
 * returns a new BTM object.  the new BTM has an empty instruction table
 * (size = 0) and an all-zero tape, its head position is 0 and its state
 * is 0.  returns NULL and sets errno if memory allocation fails.
 */
BTM *btm_new(void);

/*
 * deletes the BTM object @btm.  nothing is done if @btm is NULL.
 * preserves errno.
 */
void btm_del(BTM *btm);

/*
 * sets @btm's head position to @h and returns 0 on success.  returns
 * non-zero value and sets errno if the requested head position is beyond
 * the internally allocated tape and reallocation fails.
 */
int btm_set_head(BTM *btm, int h);

/*
 * sets @btm's state to @q and returns 0 on success.  @q can be negative
 * to set the BTM to a special "already finished" state.  returns non-zero
 * value and sets errno if @q is not a valid state.
 */
int btm_set_state(BTM *btm, int q);

/*
 * changes @btm's instruction table to set the instruction for state @q
 * and tape symbol @s to @instr and returns 0 on success.  if @q or the
 * transition target of @instr is bigger than the current highest state,
 * the instruction table will be dynamically grown to meet the need.
 * returns non-zero value and sets errno for invalid arguments (@q
 * negative, @s not '0' or '1', @instr not BTM_FIN but has negative
 * transition target) or if growing @btm's instruction table fails.
 */
int btm_set_instr(BTM *btm, int q, char s, int instr);

/*
 * copies a char array @tape to the range of @btm's tape specified by
 * @start (inclusive) and @end (exclusive), and returns 0 on success.
 * the caller shall guarantee @tape is a char array of '0's and '1's
 * that's at least @end - @start long.  returns a non-zero value and
 * sets errno for invalid arguments (@start > @end or @tape is NULL)
 * or if reallocation of @btm's tape fails.
 */
int btm_set_tape(BTM *btm, int start, int end, const char *tape);

/*
 * runs @btm until it finishes or reaches the maximum of steps @nstep.
 * on success, returns the number of steps executed (0 if @btm has already
 * finished).  if @steps is not NULL, the instructions that are executed
 * are stored into the array it points to.  returns a negative value
 * and sets errno if @nstep < 0 or dynamically growing @btm's tape fails.
 */
long long btm_run(BTM *btm, long long nstep, int *steps);

/*
 * resets @btm. that is, clears its tape, rewinds its head position to
 * 0 and sets the state to 0.
 */
void btm_reset(BTM *btm);

/*
 * returns the number of states of @btm.
 */
int btm_get_size(const BTM *btm);

/*
 * returns the head position of the given BTM.
 */
int btm_get_head(const BTM *btm);

/*
 * returns the current state of the given BTM.
 */
int btm_get_state(const BTM *btm);

/*
 * returns the instruction that would be invoked upon reading symbol @s
 * in state @q.  returns a negative value smaller than BTM_FIN and sets
 * errno if @q or @s is invalid.
 */
int btm_get_instr(const BTM *btm, int q, char s);

/*
 * returns the symbol (character '0' or '1') contained in the cell at
 * tape index @i.
 */
char btm_get_cell(const BTM *btm, int i);

/*
 * returns the piece of tape from @start (inclusive) to @end (exclusive)
 * as a null-terminated string of '0's and '1's.  memory for the string
 * is allocated with malloc(3) and the caller is responsible for freeing
 * it with free(3).
 */
char *btm_get_tape(const BTM *btm, int start, int end);

/*
 * gives the range of @btm's tape cells that has been written to (by
 * btm_set_tape() or by running the BTM).  the start (inclusive) and
 * end (exclusive) of the range are stored into the ints pointed to by
 * @start and @end, respectively.  @start or @end may be NULL and the
 * corresponding result won't be stored.
 */
void btm_get_range(const BTM *btm, int *start, int *end);

/*
 * loads the instruction table specified by @str into @btm and returns
 * 0 on success.  returns NULL and sets errno if @str doesn't contain a
 * valid string representation of instruction table or reserving enough
 * space in the instruction table fails.
 */
int btm_table_load(BTM *btm, const char *str);

/*
 * returns the string representation of @btm's instruction table.
 * memory for the string is allocated with malloc(3) and the caller is
 * responsible for freeing it with free(3).
 */
char *btm_table_dump(const BTM *btm);

/*
 * returns a new iterator for BTMs of size @size.  @flags is a bitwise
 * ORed combination of zero or more of the BTM_* flags described above.
 * if @prefix is not NULL it should be a string specifying a fixed prefix
 * of the instruction table.  @len specifies the length of the instruction
 * table to generate.  @len is measured in the number of instructions.
 * if @len is not greater than or equal to @prefix's length and less than
 * the total length, it is not in effect, otherwise the iterator will
 * iterate instruction table prefixes instead of whole instruction tables.
 *
 * returns NULL and sets errno on failure.  a failure occurs if @size < 0
 * or memory allocation for the new BTMIter object fails, or @prefix,
 * if given, doesn't contain a valid specification of an instruction
 * table prefix.  if BTM_RANDOM is in @flags, /dev/urandom is read to
 * seed a random number generator, so failure may also occur if the
 * reading fails.
 */
BTMIter *btm_iter_new(int size, int flags, const char *prefix, int len);

/*
 * deletes the BTMIter object @it.  nothing is done if @it is NULL.
 * preserves errno.
 */
void btm_iter_del(BTMIter *it);

/*
 * increments a BTM iterator @it, i.e., changes @it's internal BTM
 * object to the next one.  returns NULL if there is no next one,
 * otherwise returns @it.
 */
BTMIter *btm_iter_incr(BTMIter *it);

/*
 * returns a reference of @it's internal BTM object if @it hasn't iterated
 * past the last one, returns NULL otherwise.
 */
BTM *btm_iter_deref(const BTMIter *it);

#endif
