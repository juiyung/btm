.nr PS 11
.EQ
delim $$
.EN
.TL
A Toolkit for Attacking the Busy Beaver Problem for
.br
General and Nonerasing 2-Symbol Turing Machines
.AU
Ruiyong Xu
.R1
database bib
bracket-label " [" ] "]["
accumulate
move-punctuation
.R2
.EQ
define \{ 'type opening roman "{"'
define \} 'type closing roman "}"'
define BB 'roman "BB"'
define SP 'roman "SP"'
define mo 'type relation \[mo]'
define nm 'type relation \[nm]'
.EN
.de JS
.LP
.sp .5
.B "\\$1"
.I
..
.de JE
.P
.sp .5
..
.de OS
.LP
.B Proof.
..
.de OE
\h'\w`\(sq`u'
.br
.vs -1v
\h'|\\n(.lu-\\n(.iu-\w`\(sq`u'\(sq
.vs 1v
..
.de CS
.LP
.B1
.ID 1n
.B
.ss 20
..
.de CE
.ss 12
.P
.DE
.B2
..
.NH
Introduction
.PP
We will use the following Turing machine model.
The Turing machine's alphabet is $\{ 0, 1 \}$,
and the tape is two-way infinite.
In each step,
the head can move either one cell left or one cell right.
A Turing machine has a number of states and an instruction table,
which maps every combination of a state and a tape symbol to an instruction.
At each step,
the machine executes an instruction in its table depending on its current state and the current symbol being read on the tape.
If the instruction is ``FIN'',
the Turing machine halts (finishes),
otherwise it tells the machine which symbol to write,
which direction to move,
and which state to enter next.
We will call such a Turing machine a BTM (``Binary Turing Machine'') for short,
and we will call the number of states of a BTM its size.
.PP
The Busy Beaver game was introduced by Tibor Rad\*'o in 1962.
.[
rado
.]
It aims to find a terminating Turing machine with a given size that takes the longest number of steps to halt.
Variants of the definition of the Busy Beaver and the Beasy Beaver function exist.
In this text,
we define an $n$th Busy Beaver,
or BB-$n$,
to be a size $n$ terminating BTM that takes the longest number of steps to halt on an initially all-zero tape,
and the Busy Beaver function $BB (n)$ to be the number of steps an $n$th Busy Beaver takes before halting.
This definition of $BB (n)$ essentially agrees with the definition used by Scott Aaronson in ``The Busy Beaver Frontier''.
.[
aaronson
.]
.PP
$BB (n)$ is not computable.
In fact,
as Aaronson
.[
aaronson
.]
pointed out,
even the ability to compute any upper bound on it would imply the ability to solve the halting problem:
Given any BTM,
let $n$ be its size,
and suppose we can compute an upper bound $M$ of $BB (n)$,
then all it takes to decide if the BTM halts or not is to run it for up to $M$ steps.
If it hasn't halted yet,
then by the definition of BB,
it never will.
Given the incomputability of BB,
we don't seek to find Busy Beavers,
but Busy Beaver candidates that set potentially breakable records.
.PP
We will also seek to attack the Busy Beaver problem for nonerasing BTMs.
Nonerasing Turing machines are Turing machines that never rewrite a ``1'' on tape with a ``0''.
This computation model was proven to be Turing-complete by Maurice Margenstern.
.[
margenstern
.]
In a sense,
it simulates doing computation on paper with a nonerasable pen.
.NH
Canonical Numbering of States
.PP
Envision a BTM as a directed graph,
where the states are the nodes and the transition rules are represented as edges.
In such a graph,
every state has at most two outward edges,
one corresponding to the transition rule upon reading 0 in the state,
and the other corresponding to the transition rule upon reading 1 in the state.
(If the instruction upon reading 0 or 1 in a state is the FIN instruction,
it doesn't correspond to a transition rule and thus has no corresponding edge.)
For the purpose of introducing canonical numbering,
we mark every edge corresponding to the transition upon reading tape symbol 0 with ``0'',
and mark other edges with 1.
.PP
We number the states by integers starting from 0,
with state 0 being the initial state.
If two BTMs differ only by the numbering of states beside state 0,
it's clear that they will be behaviorally indistinguishable.
Such two BTMs correspond to two directed graphs that are isomorphic,
so it's desirable to devise a scheme of numbering the states that is hereditary to the graph.
.PP
Given a BTM of size $n$,
suppose it takes $m$ steps to halt.
We can easily extend it to a $(n + 1)$-state BTM that finishes in $m + 1$ steps:
add a state,
replace all FIN instructions in the original BTM by transitions to the additional state,
and make the instructions upon reading both symbols in the additional state to be FIN.
In particular,
the bigger a size $n$ is,
the bigger $BB (n)$ is.
Hence,
BTMs that can be reduced to a smaller size is uninteresting for our purpose.
We will thus focus on BTMs where there exists a directed path from the initial state to any other state,
since if for a BTM such a path doesn't exist for some of its states,
then those states are clearly unreachable during execution and thus the BTM trivially reduces to a smaller size.
.PP
It's worth mentioning that Aaronson
.[
aaronson
.]
conjured that Busy Beavers are all strongly connected:
that is,
every state is reachable from every other state by some sequence of transitions.
Note that this is a stronger condition than the condition of every state being reachable from the initial state.
The conjecture is somewhat intuitive but remains unproven.
.PP
Given any directed path starting from the initial state in a BTM's graph,
we encode the path by appending to 1 the sequence of marks of the edges.
So,
for example,
if state A (initial state) is connected to state B by an edge marked 0,
and state B is connected to state C by an edge marked 1,
then the path consisting of the two edges is encoded as 101.
Using this encoding we can encode states as follows:
Assign to every state the code of the shortest directed path from the initial state to it,
and when there exist multiple shortest paths,
pick the code that's smallest as a binary number.
This assigns to every state a well-defined and distinct code that's hereditary to a BTM's graph.
We will call this code of a state its ``SP-code'',
where ``SP'' stands for ``Shortest Path''.
Ascendingly sort the states into an array by their SP-codes as binary numbers,
and number the states from left to right starting from 0.
The initial state always has the smallest SP-code (which is 1) so it's always numbered 0.
This is our canonical scheme for numbering states.
.NH
Representation of Instruction Table
.PP
In the
.CW btm
C library,
an instruction is stored in a binary integer,
and the instruction table of a $n$-state BTM is represented as a $n$ by 2 array of instructions.
An integer encoding an instruction,
if equal to the special value
.CW BTM_FIN
defined in
.CW btm.h ,
means the terminating FIN instruction,
otherwise:
.IP \(bu
The least significant bit indicates the move:
0 for moving left and 1 for moving right.
.IP \(bu
The second least significant bit indicates the symbol to write:
0 for writing ``0'' and 1 for writing ``1''.
.IP \(bu
The higher bits represent an integer that indicates the next state to transit to.
.PP
In the $n$ by 2 array of instructions i.e. an array of $n$ instruction pairs,
the pair of instructions at index $q$ specifies what may be invoked in state $q$,
with the first instruction to be invoked upon reading 0 on the tape and the second upon reading 1 on the tape.
By using the current state number as the first index and the tape symbol converted to number as the second index into the $n$ by 2 array,
this array can be used as a look up table for finding the next instruction to be executed when simulating the BTM,
.PP
For the string representation of an instruction table,
the array of instruction pairs are converted as follows:
The instructions are converted one by one,
from the first pair to the last pair,
and in each pair the first instruction followed by the second.
At index $q$,
if an instruction is not FIN,
one of the letters ``o'', ``O'', ``i'', ``I'' is used to represent the move and the symbol to write,
with ``o'' and ``O'' meaning writing 0 while ``i'' and ``I'' writing 1,
lower letter indicating moving left and capital letter moving right.
If the instruction transits to state $r$ such that $r != q + 1$,
then $r$ is written as a decimal number following the letter.
The FIN instruction is converted to a single ``f''.
.NH
Properties of Canonically Numbered BTMs
.PP
From now on I will refer to states by their numbers for convenience,
so ``the state numbered $q$'' will simply be called ``state $q$''.
We will treat tape symbols ``0'' and ``1'' as numbers 0 and 1.
For further discussion,
we define $SP (q)$ to be the SP-code of state $q$ interpreted as a binary number.
A useful property of the $SP$ function follows.
.JS "Property TL{SPeq}."
In a canonically numbered BTM,
if the lowest state connecting to state $q$ is state $x$,
and the smallest symbol that can invoke a transition from state $x$ to state $q$ is $s$,
then $SP (q) = 2 SP (x) + s$.
.JE
.OS
Consider the shortest directed path from state 0 to state $q$ that defines state $q$'s SP-code.
Let state $x$ be the second last node in this path,
and suppose state $x$ transits to state $q$ upon reading symbol $s$.
It follows from the definition of the SP-code that $SP (q) = 2 SP (x) + s$,
since $2 SP (x) + s$ amounts to appending $s$ to the binary number representation of $SP (x)$.
Assume there exists state $y < x$ such that state $y$ directly connects to state $q$.
Since the states are sorted by SP-codes,
$SP (y) < SP (x)$,
which in particular means the length of the shortest directed path from state 0 to state $y$ is not more than the length of the shortest directed path from state 0 to state $x$,
and therefore the path consisting of the path from state 0 to state $y$ followed by the transition from state $y$ to state $q$ is another shortest directed path from state 0 to state $q$.
But this path corresponds to a SP-code that's at most $2 SP (y) + 1$,
which is smaller than $2 SP (x)$,
and it follows that $SP (q) <= 2 SP (y) + 1 < 2 SP (x)$,
a contradiction.
Therefore,
$x$ is the lowest state that directly connecting to state $q$.
.OE
.PP
Given a canonically numbered BTM,
let $S$ be its set of states and let $n$ be its size.
We define $t sub q,s$ to be the transition target upon reading symbol $s$ in state $q$.
If reading $s$ in state $q$ invokes FIN,
we define $t sub q,s = -1$.
Define,
for any state $i$,
$T sub i = \{ 0 \} type binary \[cu] \{ t sub q,s~|~q < i,~s mo \{ 0, 1 \} ,~t sub q,s != -1 \}$.
What follows are properties of this arbitrary canonically numbered BTM.
.JS "Property TL{self}."
$i mo T sub i$.
.JE
.OS
For $i = 0$ it's true by definition,
so we assume $i > 0$.
Suppose in a shortest directed path from state 0 to state $i$,
the second last state,
which directly connects to state $i$,
is state $q$.
That means there exists $s mo \{ 0, 1 \}$ such that $i = t sub q,s$.
Since the path from state 0 to state $q$ is shorter than the path from state 0 to state $i$,
$SP (q) < SP (i)$,
so $q < i$ by the increasingness of SP-codes.
Since $q < i$ and $t sub q,s = i != -1$,
$t sub q,s mo T sub i$.
.OE
.JS "Property TL{span}."
$T sub i = \{ q mo S~|~0 <= q <= max T sub i \}$.
.JE
.OS
It's clear that $T sub j type relation \[ip] T sub j-1$ for $j > 0$,
so as a corollary of Property TR{self},
$T sub 0 type relation \[ip] \{ 0 \}$,
$T sub 1 type relation \[ip] \{ 0, 1 \}$,
$T sub 2 type relation \[ip] \{ 0, 1, 2 \}$,
and so on,
so we have $T sub i type relation \[ip] \{ q mo S~|~0 <= q <= i \}$.
On the other hand,
obviously no $q > max T sub i$ belongs to $T sub i$.
So it remains to show that $\{ q mo S~|~i < q <= max T sub i \} type relation \[ib] T sub i$.
.PP
Let $m = max T sub i$.
Assume there exists state $q$ with $i < q <= m$ such that $q nm T sub i$.
$q != m$ as $m mo T sub i$ by definition.
Since there is a sequence of transitions from state 0 to state $q$,
there exists a lowest state $x$ such that $t sub x,a = q$ for some $a mo \{ 0, 1 \}$.
Since $t sub x,a = q nm T sub i$,
by the definition of $T sub i$,
$x >= i$.
Let state $y$ be the lowest state such that $t sub y,b = m$ for some $b mo \{ 0, 1 \}$,
then $t sub y,b = m mo T sub i$ and thus $y < i$.
We have $y < i <= x$,
so,
by the increasingness of SP-codes,
$SP (y) < SP (x)$.
By Property TR{SPeq},
$SP (q) = 2 SP (x) + a$ and $SP (m) = 2 SP (y) + b$.
Since $SP (x) > SP (y)$ and $a, b mo \{ 0, 1 \}$,
$SP (q) > SP (m)$,
violating the constraint of ascending SP-codes.
Therefore,
$q nm T sub i$ is impossible.
.OE
.PP
Property TR{span} shows that $T sub i$ is characterized by its maximum.
Let's define $M sub i = max T sub i$.
.JS "Property TL{pull}."
For $i < n - 1$,
$M sub i+1 <= M sub i + 2$,
and when $M sub i+1 = M sub i + 2$,
$t sub i,0 = M sub i + 1$ and $t sub i,1 = M sub i + 2$.
.JE
.OS
Using Property TR{span},
$T sub i+1 type binary \\ T sub i = \{ q mo S~|~M sub i < q <= M sub i+1 \}$ so $|T sub i type binary \\ T sub i | = M sub i+1 - M sub i$,
On the other hand,
$T sub i+1 type binary \\ T sub i type relation \[ib] \{ t sub i,0 , t sub i,1 \}$ so $|T sub i+1 type binary \\ T sub i | <= 2$.
Thus $M sub i+1 - M sub i <= 2$.
.PP
When $M sub i+1 = M sub i + 2$,
$\{ M sub i + 1 , M sub i + 2 \} = T sub i+1 type binary \\ T sub i type relation \[ib] \{ t sub i,0 , t sub i,1 \}$,
so $\{ t sub i,0 , t sub i,1 \} = \{ M sub i + 1 , M sub i + 2 \}$.
Assume $t sub i,0 = M sub i + 2$,
then $t sub i,1 = M sub i + 1$.
In that case,
state $i$ is the lowest state directly connecting to state $M sub i + 1$ and also the lowest state directly connecting to $M sub i + 2$,
the transition to state $M sub i + 1$ is invoked upon reading 0,
and the transition to state $M sub i + 2$ is invoked upon reading 1,
so by Property TR{SPeq},
$SP (M sub i + 1) = 2 SP (i) + 1$ and $SP (M sub i + 2) = 2 SP (i)$,
making $SP (M sub i + 1) > SP (M sub i + 2)$,
a violation of the constraint of ascending SP-codes.
Therefore,
the only possibility is $t sub i,0 = M sub i + 1$ and $t sub i,1 = M sub i + 2$.
.OE
.JS "Property TL{pair}."
For $i < n - 1$,
$t sub i,0 <= M sub i + 1$,
and when $t sub i,0 <= M sub i$,
$t sub i,1 <= M sub i + 1$.
.JE
.OS
If $M sub i <= M sub i + 1$,
then $t sub i,0 <= M sub i <= M sub i + 1$.
Otherwise,
$M sub i+1 = M sub i + 2$,
and by Property TR{pull},
$t sub i,0 = M sub i + 1$ so it holds that $t sub i,0 <= M sub i + 1$.
If $t sub i,0 <= M sub i$,
then $M sub i+1 <= M sub i + 1$,
for otherwise $M sub i+1 = M sub i + 2$ and we have $t sub i,0 = M sub i + 1$.
Thus $t sub i,1 <= M sub i+1 <= M sub i + 1$.
.OE
.NH
Conditions Guarding Canonical Numbering
.PP
For now we define a ``preliminarily numbered BTM'' to be a BTM where states are numbered from 0 to $n - 1$,
where $n$ is the BTM's size and the initial state is numbered 0.
A preliminarily numbered BTM with correct transitions becomes canonically numbered.
Note that,
while the quantities $t sub q,s$, $T sub i$ and $M sub i$ are defined for canonically numbered BTMs in the previous section,
the definitions are applicable to preliminarily numbered BTMs.
.JS "Theorem TL{guard}."
A preliminarily numbered BTM of size $n$ is canonically numbered iff the following conditions hold for every state $i < n - 1$:
.IP (1)
.I
$t sub i,0 <= M sub i + 1$.
.IP (2)
.I
If $t sub i,0 <= M sub i$ and $M sub i = i$,
then $t sub i,1 = M sub i + 1$.
.IP (3)
.I
If $t sub i,0 <= M sub i$ and $M sub i > i$,
then $t sub i,1 <= M sub i + 1$.
.IP (4)
.I
If $t sub i,0 = M sub i + 1$,
then $t sub i,1 <= M sub i + 2$.
.JE
.PP
A few lemmas are established before proving the theorem.
In the ``Canonical Numbering of States'' section,
a way to encode any path into a binary code is introduced and the encoding is used to define SP-codes of states.
For now we call this code of a path its binary code.
.JS "Lemma TL{lemma1}."
In a preliminarily numbered BTM,
if the four conditions in Theorem TR{guard} hold for every state $i < n - 1$,
then $M sub i >= i$ for every state $i$.
.JE
.OS
We use induction on $i$.
$T sub 0 = \{ 0 \}$ by definition so $M sub 0 = 0$.
Thus it holds for $i = 0$.
For $i < n - 1$,
we assume $M sub i >= i$ to prove $M sub i+1 >= i + 1$.
If $M sub i > i$ i.e. $M sub i >= i + 1$,
then $M sub i+1 >= M sub i >= i + 1$.
Assume $M sub i = i$.
By (1),
$t sub i,0 <= M sub i + 1$.
If $t sub i,0 = M sub i + 1$,
$M sub i+1 >= t sub i,0 = M sub i + 1 >= i + 1$.
Otherwise,
$t sub i,0 <= M sub i$ and $M sub i = i$,
so $t sub i,1 = M sub i + 1$ by (2),
and thus $M sub i+1 >= t sub i,1 = M sub i + 1 >= i + 1$.
So $M sub i+1 >= i + 1$ in every case.
The induction is completed.
.OE
.JS "Lemma TL{lemma2}."
Given a preliminarily numbered BTM and a state $i$,
if the SP-codes of states 0 to $M sub i$ are defined and increasing,
then $SP (M sub i ) < 2 SP (i)$,
and for any state $q > M sub i$ that's reachable from state 0 via a directed path,
$SP (q) >= 2 SP (i)$.
.JE
.OS
Let state $x$ be the lowest state that directly connects to state $M sub i$.
Since $M sub i mo T sub i$,
by the definition of $T sub i$,
there exists some state below $i$ that directly connects to state $M sub i$,
so $x < i$.
Since the SP-codes of states 0 to $M sub i$ are increasing,
$SP (x) < SP (i)$.
Let $P sub x$ be the path from state 0 to state $x$ whose binary code is equal to $SP (x)$,
and let $P sub {M sub i}$ be the path constructed by appending to $P sub x$ a transition from state $x$ to state $M sub i$.
The SP-code of state $M sub i$ is at most the binary code of $P sub {M sub i}$,
which is the binary code of $P sub x$ with 0 or 1 appended and thus at most $2 SP (x) + 1$.
So $SP (M sub i ) <= 2 SP (x) + 1$,
where $2 SP (x) + 1 < 2 SP (i)$ since $SP (x) < SP (i)$.
Thus $SP (M sub i ) < 2 SP (i)$.
.PP
Let state $q$ be a state above $M sub i$ that's reachable from state 0,
and let $P sub q$ be a shortest path from state 0 to state $q$.
Since $0 <= M sub i < q$ where state 0 and state $q$ belong to $P sub q$,
there exists state $x$ in $P sub q$ such that $x <= M sub i$ and the next state $y$ in $P sub q$ satisfies $y > M sub i$.
Since $y > M sub i$,
by the definition of $M sub i$,
no state below $i$ directly connects to state $y$,
so $x >= i$.
Since $i <= x <= M sub i$ and the SP-codes of states 0 to $M sub i$ are increasing,
$SP (x) >= SP (i)$.
The binary code of the portion of $P sub q$ from state 0 to state $x$ is at least $SP (x)$,
so the binary code of $P sub q$,
which contains at least one transition after state $x$,
is at least $2 SP (x)$ and thus at least $2 SP (i)$ since $SP (x) >= SP (i)$.
Since the $2 SP (i)$ lower bound holds for an arbitrary shortest path $P sub q$ from state 0 to state $q$,
$SP (q) >= 2 SP (i)$.
.OE
.JS "Lemma TL{lemma3}."
Given a preliminarily numbered BTM of size $n$ and a state $i < n - 1$,
assume the SP-codes of states 0 to $M sub i$ are defined and increasing.
If $t sub i,0 > M sub i$,
then $SP (t sub i,0 ) = 2 SP (i)$.
If $t sub i,1 > M sub i$ and $t sub i,0 != t sub i,1$,
then $SP (t sub i,1 ) = 2 SP (i) + 1$.
.JE
.OS
Assume $t sub i,0 > M sub i$.
Let $P sub i$ be the path from state 0 to state $i$ whose binary code is equal to $SP (i)$.
Construct path $P sub t$ by appending to $P sub i$ the transition from state $i$ to state $t sub i,0$ that's invoked by reading 0.
The binary code of the resulting path is $2 SP (i)$.
On the other hand,
$SP (t sub i,0 ) >= 2 SP (i)$ by Lemma TR{lemma2}.
Hence the binary code of $P sub t$ is the SP-code of $t sub i,0$,
i.e.,
$SP (t sub i,0 ) = 2 SP (i)$.
.PP
Instead of $t sub i,0 > M sub i$,
assume $t sub i,1 > M sub i$ and $t sub i,0 < t sub i,1$.
Let $P sub i$ be the path from state 0 to state $i$ whose binary code is equal to $SP (i)$.
Construct a path $P sub t$ by appending to $P sub i$ the transition from state $i$ to state $t sub i,1$,
which is invoked by reading 1.
The binary code of the resulting path is $2 SP (i) + 1$.
What remains is to show that $P sub t$'s binary code is minimal among shortest paths from state 0 to state $t sub i,1$.
.PP
Let $P'$ be a shortest path from state $0$ to state $t sub i,1$,
and let state $x$ be the second last state in $P'$.
The binary code of $P'$ is at least $2 SP (x)$.
If $x > M sub i$,
then $SP (x) >= 2 SP (i)$ by Lemma TR{lemma2},
so $2 SP (x) > 2 SP (i) + 1$.
Thus $P'$ has a bigger binary code than $P sub t$'s.
So assume $x <= M sub i$.
By the definition of $M sub i$,
no state below $i$ directly connects to state $t sub i,1 > M sub i$,
so $x >= i$ since $x$ directly connects to $t sub i,1$.
If $x > i$,
since states 0 to $M sub i$ have increasing SP-codes and $x <= M sub i$,
we have $SP (x) > SP (i)$ and thus the binary code of $P'$ is at least $2 SP (x) > 2 SP (i) + 1$,
so $P'$ has a bigger binary code than $P sub t$.
If $x = i$,
then,
since it's assumed that $t sub i,0 != t sub i,1$,
the transition from state $x = i$ to state $t sub i,1$ is invoked by reading 1,
so the binary code of $P'$ is the binary code of the portion of $P'$ from state 0 to state $x$ with 1 appended,
which is at least $2 SP (x) + 1 = 2 SP (i) + 1$.
Therefore,
$P sub t$'s binary code is minimal and we have $SP (t sub i,1 ) = 2 SP (i) + 1$.
.OE
.PP
Here is the proof of Theorem TR{guard}.
.OS
If the BTM is canonically numbered,
then (1) and (3) follows from Property TR{pair}.
(4) follows from the part of Property TR{pull} saying that $M sub i+1 <= M sub i + 2$.
As for (2),
if $M sub i = i$ but both $t sub i,0$ and $t sub i,1$ are not greater than $M sub i$,
then both $t sub i,0$ and $t sub i,1$ are smaller than $i + 1$ so $M sub i+1 < i + 1$,
meaning $i + 1 nm T sub i+1$ and thus breaking Property TR{self}.
Next we work on the other direction,
that is,
we assume conditions (1) to (4) and prove the BTM is canonically numbered.
.PP
In the base case $i = 0$,
we have $M sub 0 = 0$,
and (1) restricts $t sub 0,0$ to be -1, 0 or 1.
If $t sub 0,0 <= 0$ then (2) sets $t sub 0,1 = 1$.
In this case,
$M sub 1 = 1$ and $SP (1) = 11 sub 2 > 1 = SP (0)$,
the SP-codes of states 0 to $M sub 1$ are increasing.
If $t sub 0,0 = 1$ then (3) says $t sub 0,1$ may be -1, 0, 1 or 2.
In this case,
$SP (1) = 10 sub 2$ regardless of what $t sub 0,1$ is,
so the SP-codes of states 0 and 1 are increasing.
If $t sub 0,1 <= 1$,
then $M sub 1 = 1$ and it's done.
Otherwise,
$t sub 0,1 = 2$ and $M sub 1 = 2$,
$SP (2) = 11 sub 2 > 10 sub 2 = SP (1)$ so the SP-codes of states 0 to $M sub 1$ are increasing.
.PP
Let $0 < i < n - 1$.
The hypothesis is that the SP-codes of states 0 to $M sub i$ are increasing and we will prove that the SP-codes of states 0 to $M sub i+1$ are increasing.
$t sub i,0 <= M sub i + 1$ by condition (1),
and $M sub i >= i$ by Lemma TR{lemma1},
so these are all the cases:
.IP "$t sub i,0 = M sub i + 1$:"
In this case,
$t sub i,1 <= M sub i + 2$ by (4).
Since $t sub i,0 = M sub i + 1$,
$SP (M sub i + 1 ) = 2 SP (i)$ by Lemma TR{lemma3}.
On the other hand,
$SP (M sub i ) < 2 SP (i)$ by Lemma TR{lemma2}.
So $SP (M sub i ) < SP (M sub i + 1)$.
If $t sub i,1 <= M sub i + 1$,
then $M sub i+1 = M sub i + 1$ and we are done with the case.
If $t sub i,1 = M sub i + 2$,
then $M sub i+1 = M sub i + 2$,
and we have $SP (M sub i + 2) = 2 SP (i) + 1$ by Lemma TR{lemma3},
so $SP (M sub i + 2) > SP (M sub i + 1)$.
The SP-codes of states 0 to $M sub i+1$ remain increasing.
.IP "$t sub i,0 <= M sub i$ and $M sub i = i$:"
In this case,
$t sub i,1 = M sub i + 1$ by (2),
and $M sub i+1 = M sub i + 1$.
$SP (M sub i + 1) = 2 SP (i) + 1$ by Lemma TR{lemma3},
and $SP (M sub i ) < 2 SP (i)$ by Lemma TR{lemma2},
so $SP (M sub i ) < SP (M sub i + 1)$.
The SP-codes of states 0 to $M sub i+1$ are increasing.
.IP "$t sub i,0 <= M sub i$ and $M sub i > i$:"
In this case,
$t sub i,1 <= M sub i + 1$ by (3).
If $t sub i,1 <= M sub i$ then $M sub i+1 = M sub i$ and it's done.
Assume $t sub i,1 = M sub i + 1$,
in which case $M sub i+1 = M sub i + 1$.
$SP (M sub i + 1) = 2 SP (i) + 1$ by Lemma TR{lemma3},
and $SP (M sub i ) < 2 SP (i)$ by Lemma TR{lemma2},
so $SP (M sub i ) < SP (M sub i + 1)$.
The SP-codes of states 0 to $M sub i+1$ are increasing.
.PP
Hence the induction step is established,
and as the conclusion,
states 0 to $M sub n-1$ have increasing SP-codes.
$M sub n-1 >= n - 1$ by Lemma TR{lemma1},
and $M sub n-1$ is itself a state,
so $M sub n-1 = n - 1$.
Therefore all states have increasing SP-codes.
.OE
.NH
Enumeration Algorithm
.PP
By the four conditions in Theorem TR{guard},
for a state $i$,
once the transitions of states below it are known,
then $M sub i$ is known and the valid choices of transitions in state $i$ can be determined.
.PP
Given that,
all it takes to perform random generation of instruction tables that's canonically numbered is to make a random valid choice of transition for each instruction from the beginning and randomly fill the symbol to write and the move in each non-FIN instruction.
The following is the pseudocode for randomly filling a $n$ by 2 instruction table such that it's canonically numbered.
We use an transition target (the ``next_state'' field) of -1 to indicate the FIN instruction.
.EQ
define table 'roman "table[" $1 roman "][" $2 roman "].$3"'
define target 'table($1,$2,next_state)'
.EN
.CS
$M sub 0 <- 0$
for $i <- 0$ to $n - 2$:
    $target(i,0) <-$ random integer from $-1$ to $min \{ M sub i + 1, n - 1 \}$
    if $target(i,0) = M sub i + 1$:
        $target(i,1) <-$ random integer from $-1$ to $min \{ M sub i + 2, n - 1 \}$
    else if $M sub i = i$:
        $target(i,1) <- M sub i + 1$
    else:
        $target(i,1) <-$ random integer from $-1$ to $min \{ M sub i + 1, n - 1 \}$
    $M sub i+1 <- max \{ M sub i , target(i,0), target(i,1) \}$
$target(n-1,0) <-$ random integer from $-1$ to $n - 1$
$target(n-1,1) <-$ random integer from $-1$ to $n - 1$
for $i <- 0$ to $n - 1$:
    for $j <- 0$ to $1$:
        if $target(i,j) != -1$:
            $table(i,j,write) <-$ random element of $\{ 0, 1 \}$
            $table(i,j,move) <-$ random element of $\{ L, R \}$
.CE
.PP
For ordered enumeration,
the process is analogous to incrementing a number with each instruction being a ``digit''.
The distinction is just that the range of a ``digit'' is not fixed but determined by the ``digits'' to its left.
The pseudocode for enumeration is a bit complex,
so I factored out some subroutines.
.PP
The ``Reset'' subroutine sets every instruction in the table starting from a given state to the ``lowest'' value permitted by canonically numbering,
and sets $M sub i$ accordingly.
.CS
define \fRReset(start)\fP:
    for $i <- roman "start"$ to $n - 2$:
        $target(i,0) <- -1$
        if $M sub i = i$:
            $target(i,1) <- i + 1$
            $table(i,1,write) <- 0$
            $table(i,1,move) <- L$
            $M sub i+1 <- i + 1$
        else:
            $target(i,1) <- -1$
            $M sub i+1 <- M sub i$
    $target(n-1,0) <- -1$
    $target(n-1,1) <- -1$
.CE
.PP
The ``IncAction'' subroutine finds,
starting from the last state,
an action (which symbol to write and which direction to move) that can be ``increased'',
then ``increases'' it and resets actions in subsequent instructions.
Returns whether it can be done.
.CS
define \fRIncAction()\fP:
    $roman done <-$ false
    for $i <- n - 1$ down to $0$:
        for $j <- 1$ down to $0$:
            if $target(i,j) != -1$:
                if $table(i,j,move) = L$:
                    $table(i,j,move) <- R$
                    $roman done <-$ true
                else if $table(i,j,write) = 0$:
                    $table(i,j,write) <- 1$
                    $table(i,j,move) <- L$
                    $roman done <-$ true
                if $roman done$:
                    if $j = 0$:
                        $table(i,1,write) <- 0$
                        $table(i,1,move) <- L$
                    for $k <- i + 1$ to $n - 1$:
                        for $l <- 0$ to $1$:
                            $table(k,l,write) <- 0$
                            $table(k,l,move) <- L$
                    return true
    return false
.CE
.PP
``IncTransitionAt'' is an auxiliary subroutine of ``IncTransition''.
It increases the indicated instruction,
resets the action,
and resets all subsequent instructions.
.CS
define $roman IncTransitionAt (i, j)$:
    $target(i,j) <- target(i,j) + 1$
    $table(i,j,write) <- 0$
    $table(i,j,move) <- L$
    if $j = 0$:
        if $target(i,0) <= M sub i$ and $M sub i = i$:
            $target(i,1) <- i + 1$
            $table(i,1,write) <- 0$
            $table(i,1,move) <- L$
        else:
            $target(i,1) <- -1$
    if $i < n - 1$:
        $M sub i+1 <- max \{ M sub i , target(i,0), target(i,1) \}$
        $roman Reset (i + 1)$
.CE
.PP
The ``IncTransition'' subroutine finds,
starting from the last state,
a transition (possibly -1 for a FIN instruction) that can be increased and increase it with ``IncTransitionAt''.
Returns whether it can be done.
.CS
define \fRIncTransition()\fP:
    for $j <- 1$ down to $0$:
        if $target(n-1,j) < n - 1$:
            $roman IncTransitionAt (n-1,j)$
            return true
    for $i <- n - 2$ down to $0$:
        if $target(i,0) = M sub i + 1$:
            if $target(i,1) < min \{ M sub i + 2, n - 1 \}$:
                $roman IncTransitionAt (i, 1)$
                return true
        else if $M sub i > i$:
            if $target(i,1) < min \{ M sub i + 1, n - 1 \}$:
                $roman IncTransitionAt (i, 1)$
                return true
        if $target(i,0) < min \{ M sub i + 1, n - 1 \}$:
            $roman IncTransitionAt (i,0)$
            return true
    return false
.CE
.PP
Lastly,
this is the pseudocode showing how to enumerate and output all canonically numbered BTMs:
.CS
$M sub 0 <- 0$
$roman Reset (0)$
$roman transition_new <-$ true
while \fRtransition_new\fP:
    $roman action_new <-$ true
    while $roman action_new$:
        output \fRtable\fP
        $roman action_new <- roman IncAction ()$
    $roman transition_new <- roman IncTransition ()$
.CE
.NH
Minimizing Search Space
.PP
We have excluded BTMs with any state disconnected from state 0,
and the canonical numbering of states has eliminated equivalences that are different only by renumbering of states.
Here are more ways to cut out equivalent or otherwise unvaluable BTMs are available.
.PP
Two BTMs ``mirror'' each other if their instruction tables are the same except that,
for every instruction in one of the instruction tables where the move is rightward,
the counterpart in the other instruction table has the move being leftward,
and vice versa.
On an initially all-zero tape that's infinite in both directions,
obviously two mirrored BTMs will do basically the same thing.
Specifically,
the configuration of one of the BTMs after any given number of steps can be trivially obtained from the configuration of the other after the same number of steps.
In particular,
they will terminate in the same number of steps,
so for our purpose we can drop one of the mirrored pair.
We do so by excluding BTMs whose first instruction in its instruction table contains a move to left.
That doesn't rule out any instruction table where the first instruction is FIN,
but those will just terminate immediately so we can simply rule out all of them.
.PP
Obviously if we want a BTM to finish,
its instruction table shall contain at least one FIN instruction.
For our purpose of finding BTMs that halt after the most steps,
it's also helpful to require the instruction table to contain only one FIN instruction.
Suppose a BTM with multiple FIN instructions in its instruction table halts after certain number of steps.
There is only one specific FIN instruction that's invoked at the end,
so clearly the other FIN instructions are never used and may be replaced by any other instruction without affecting the execution of the BTM,
Hence,
by replacing all the other FIN instructions by instructions other than FIN,
we can obtain a BTM with exactly one FIN in its instruction table that halts in the same number of steps.
Therefore it suffices to consider BTMs with only one FIN in their instruction tables.
.PP
If a subset of states of a BTM don't transit to states outside the subset itself,
and instruction table entries for this subset of states don't contain a FIN instruction,
then either these states are never reached during the BTM's execution and the BTM effectively has a smaller size,
or they are reached at some point and then the FIN instruction won't possibly be invoked,
so such a BTM is uninteresting for our purpose.
This is a generalization of the particular condition where there is a state that loops back to itself upon both reading 0 and reading 1.
We call such a BTM ``separable''.
To detect this,
we first mark states where FIN may be invoked,
then recursively mark states that directly connects to some marked state,
until no more state can be marked.
If there exist states that are unmarked by the end,
they are the ``separable'' subset that makes the BTM excludable.
.PP
Certain prefixes of the instruction tables can be ruled out to further minimize the search space.
That's left to be explained in the ``Elimination of Prefixes'' section below.
.NH
The \fCbtm\-enum\fP and \fCbtm\-emul\fP Programs
.LP
The two programs are written in C and built on top of the
.CW btm
library.
(The library's API is documented in the
.CW btm.h
header.)
They're used to write scripts (introduced later) for attacking our problems.
.IP "\(bu \ \ \fCbtm\-enum\fP"
.CW btm\-enum
is a command line utility for the enumeration of (instruction tables of) BTMs.
In its simplest usage,
it takes an numerical argument specifying the BTM size,
uses the enumeration algorithm described previously to orderedly enumerate all BTMs of that size,
and prints their string representations,
one per line.
.IP
The flags
.CW \-e
causes it to enumerate only nonerasing BTMs.
The flags
.CW \-m
and
.CW \-s
can be specified to avoid,
respectively,
mirrored and separable BTMs,
in the sense described in the ``Minimizing Search Space'' section.
The
.CW \-f
and
.CW \-u
flags restricts the number of FIN instructions in BTM's instruction table to be at least 1 and at most 1,
respectively.
.CW \-f
and
.CW \-u
used together make every generated BTM to have exactly one FIN in its instruction table.
.IP
.CW btm\-enum
supports specifying a range of step numbers that BTMs must terminate within (starting with an all-zero tape) with the
.CW \-t
option.
The option argument can either be a single number for a minimum number of steps,
or two numbers separated by a comma,
the first specifying the minimum and the second the maximum.
.IP
.CW btm\-enum
can perform random generation if the
.CW \-r
option is given.
This options takes a number for the maximum number of random BTMs to generate for testing for,
e.g.,
separability and the number of steps it can run.
If the argument is a negative number,
there won't be a bound on the number of trials and the generation will not stop unless a maximum number of output specified with the
.CW \-n
option is met (or the program is interrupted).
.IP
.CW btm\-enum
has other options,
to be introduced among later sections.
.IP "\(bu \ \ \fCbtm\-emul\fP"
The
.CW btm\-emul
command line utility is for the emulation of BTMs.
It takes one or more BTM specifications either from command line arguments or,
if there is no argument,
from standard input.
Each BTM specification consists of a string representation of the instruction table optionally followed by a configuration specification.
By default,
.CW btm\-emul
emulates each BTM step by step for at most 50 steps (can be changed with the
.CW \-n
option) and before the first step and after each step,
prints the the BTM's configuration prefixed by a step count and a colon.
At the end of each BTM's emulation it a summary line is printed,
which is either
.DS
.CW "[...] finished in [...] steps"
.DE
or
.DS
.CW "[...] continues after [...] steps"
.DE
The subject in both sentences is a string representation of the BTM's instruction table.
.IP
The configuration specification is a string of ``0''s and ``1''s specifying a contagious piece of tape cells,
where on the right of one of the tape cell there should be a state number enclosed by parentheses,
indicating the starting head position and state.
Tape cells not covered by this specification are considered all-zero.
The default initial configuration in the absence of configuration specification is
.CW 0(0) ,
i.e.,
an all-zero tape with the starting state being 0.
.IP
The configuration printed in each step (if not canceled by the
.CW -s
option) follows the same format as configuration specification,
and only tape cells that have been written to by the BTM during emulation,
or have been set with the BTM specification,
are shown.
.IP
The
.CW \-n
option accepts a number setting the maximum number of steps to emulate every BTM.
If this number is not positive,
there is no upper bound on the number of steps (useful when the BTMs to emulate are known to terminate).
When the
.CW \-s
option is given,
only the summary line is printed for each BTM.
.IP
Options
.CW -c
and
.CW -b
were implemented mainly for the convenience of scripting (they're used in the
.CW btm\-cont
script).
If the
.CW \-c
option is given,
the summary line for each BTM that didn't terminate within the maximum number of steps becomes
.DS
.CW "[...] continues after [...] steps: [BTM spec]"
.DE
where the part following the colon is a BTM specification in the form that can be passed back to
.CW btm\-emul ,
either as an argument or a line in standard input,
to continue the emulation.
The
.CW \-b
option takes a number indicating how many steps the BTMs have already been run,
which affects the step count in summary lines as well as the step counts prefixing the configuration printed in each step.
.NH
BTM Counts
.PP
The table below shows the number of unique canonically numbered BTMs (or BTM instruction tables, to be precise) of different types and sizes,
with those whose first instruction in instruction table is FIN,
and mirrored equivalences,
excluded.
Each correspond to the would-be output of running such a command:
.DS
.CW "./btm\-enum -mfu -t 2 TYPE SIZE | wc -l" .
.DE
where
.CW TYPE
.CW \-e
or empty.
.KS
.TS
center,box;
c|c|c
c|n|n.
Size	#BTM	#Nonerasing BTM
_
2	512\&	208\&
3	152,064\&	29,952\&
4	60,162,048\&	5,849,088\&
5	$approx 3.00 times 10 sup 10$\&	$approx 1.44 times 10 sup 9\0$\&
6	$approx 1.79 times 10 sup 13$\&	$approx 4.29 times 10 sup 11$\&
7	$approx 1.25 times 10 sup 16$\&	$approx 1.49 times 10 sup 14$\&
8	$approx 1.00 times 10 sup 19$\&	$approx 5.94 times 10 sup 16$\&
9	$approx 8.94 times 10 sup 21$\&	$approx 2.66 times 10 sup 19$\&
10	$approx 8.91 times 10 sup 24$\&	$approx 1.33 times 10 sup 22$\&
11	$approx 9.76 times 10 sup 27$\&	$approx 7.25 times 10 sup 24$\&
12	$approx 1.17 times 10 sup 31$\&	$approx 4.33 times 10 sup 27$\&
13	$approx 1.51 times 10 sup 34$\&	$approx 2.79 times 10 sup 30$\&
14	$approx 2.10 times 10 sup 37$\&	$approx 1.94 times 10 sup 33$\&
15	$approx 3.13 times 10 sup 40$\&	$approx 1.45 times 10 sup 36$\&
.TE
.KE
.PP
These numbers are obtained from calculation.
They do not take into account separable BTMs or other kinds of elimination,
which would make the calculation more difficult,
but they offer a good sense of the quantity that we need to handle.
.PP
The calculation of these numbers are quite involved.
Since these numbers are not particularly important here,
I will omit a full explanation.
But here are some related equations,
just to give some idea to the interested.
Suppose $u sub j$ is the number of canonically numbered $j$-state BTMs without FIN in their instruction tables,
$v sub j$ is the number of canonically numbered $j$-state BTMs with exactly one FIN in their instruction tables,
and $w sub j$ the number of canonically numbered $j$-state BTMs whose first instruction in their instruction tables is FIN.
Then:\**
.FS
Underlined superscripts denote falling factorials.
.FE
.EQ
sum from j=1 to i (i - 1) sup {j-1 under}^(4i) sup 2(i-j) u sub j = (4i) sup 2i~~~~(i = 1, 2, 3, ... )
.EN
.EQ
sum from j=1 to i (i - 1) sup {j-1 under}^left ( (4i) sup 2(i-j) v sub j + 2(i - j)^(4i) sup 2(i-j)-1 u sub j right ) = 2i^(4i) sup 2i-1~~~~(i = 1, 2, 3, ... )
.EN
.EQ
sum from j=1 to i (i - 1) sup {j-1 under}^(4i) sup 2(i-j) w sub j = (4i) sup 2i-1~~~~(i = 1, 2, 3, ... )
.EN
Once $v sub n$ and $w sub n$ are solved for from these systems of equations,
the number of canonically numbered $n$-state BTMs with exactly one FIN (not the first instruction) and with mirrored equivalences excluded is ${v sub n - w sub n} over 2$.
The calculation of the number of $n$-state nonerasing BTMs is analogous.
.NH
Detecting Looping BTMs
.PP
We deploy a heuristic method to detect looping BTMs,
who infinitely repeat some steps so can never finish.
After running a BTM for a number of steps,
to heuristically check if it's starting to repeat some steps indefinitely,
we run it for an additional number of steps and record instructions it executes,
and then check if these instructions are repetitive for more than a certain number of times,
and if so we exclude the BTM.
Obviously,
neither is this method guaranteed to detect all BTMs that end up looping,
nor is it guaranteed to not give false positives.
But a reasonable combination of parameters can be expected to make the method work well.
I would say if the number of steps recorded for repetition detection is twice the steps the BTM has already executed before,
and the number of repetition in the recorded instructions is not less than 3,
this detection method will be practically effective.
.PP
How to efficiently detect repetition in a sequence of instructions?
Suppose there is a sequence of $n$ instructions,
and the required minimum number of repetitions is $z$.
A potential period $p$ is at most $size -2 {left floor n over z right floor}$.
The possibilities can be further reduced by noting that if the instructions repeat with period $p$,
then the $(p + 1)$th, $(2p + 1)$th, $(3p + 1)$th etc. instructions must all be equal to the 1st instruction.
So we find candidate periods by starting with $p = 1$ and increasing it up to $size -2 {left floor n over z right floor}$,
and for each $p$ we check if any of the $(p + 1)$th, $(2p + 1)$th, etc., up until the $n$th instruction is different from the 1st instruction,
and if so exclude it.
In general this will quickly rule out most false periods.
For each of the few candidate periods that remain,
if any,
we straightforward verify whether the instructions do repeat with that period.
.EQ
define minrep "\fCminrep\fP"
.EN
.PP
The option
.CW \-z
of
.CW btm\-enum
is provided for such detection.
It takes an argument consisting of two values
.CW minrep
and
.CW index ,
separated by a comma.
When this option is given,
for each BTM,
and for $n$ equal to each of $minrep$, $2 cdot minrep$, $4 cdot minrep$, ... , $2 sup \fCindex\fP-1 cdot minrep$,
the program tests whether the $2n$ steps following the first $n$ steps repeat for at least
.CW minrep
times,
and if so the BTM is excluded as looping.
The $2 cdot minrep$ recorded steps after the first $minrep$ steps overlap the $4 cdot minrep$ recorded steps after the first $2 cdot minrep$ steps,
which overlap the $8 cdot minrep$ recorded steps after the first $4 cdot minrep$ steps,
and so on.
The program reuses the overlapped part so that the execution of BTMs never needs to be rewind.
.PP
Some BTMs demonstrate behaviors similar to the following:
execute certain sequence of instructions a number of times before executing some other instructions,
then go back to repeating the same sequence of instructions more times,
and so on,
infinitely.
Such BTMs would escape the simple repetition detection,
but would appear to be looping and detected after deduplication of their steps.
The
.CW \-d
option of
.CW btm\-enum
does such deduplication.
The argument
.CW duplen
that it takes is the maximum length of instruction sequence that will be considered for deduplication.
The duplication detection is done just the simple way:
At each recorded instruction,
check if the 1, 2, 3, ... ,
.CW duplen
instructions starting there are immediately repeated,
and if so,
remove subsequent repetitions and skip to the end of the duplicated instructions.
After deduplication,
the number of recorded instructions will probably be reduced,
and repetition detection is detected in the $2 smallover 3$ tail to exclude those that appear to be looping after deduplication.
.NH
Elimination of Prefixes
.PP
The enumeration can be carried out for a specific prefix of the instruction table.
.CW btm\-enum 's
.CW \-p
option is for this.
The prefix taken by
.CW btm\-enum 's
.CW \-p
option must be of a canonically numbered BTM,
so it's required that the given prefix satisfies the conditions in Proposition TR{guard}.
Besides generating for a prefix,
.CW btm\-enum
can also produce prefixes with the use of the
.CW \-l
option,
whose argument specifies the prefix length.\**
.FS
When talking about instruction table prefixes,
the length refers to the number of instructions rather than the string length.
.FE
.PP
Some prefixes can be excluded to reduce the search space.
For example:
.IP \(bu
If a BTM's instruction table begins with
.CW f
then (given that the tape is initially all-zero) it will terminate in just one step
so prefixes beginning with
.CW f
can be excluded.
.IP \(bu
If a BTM's first instruction in its table is a transition to state 0,
then it will certainly loop infinitely,
so prefixes with a
.CW 0
immediately following the first letter can be excluded.
.IP \(bu
Now that the first instruction can be neither
.CW f
nor a transition to state 0,
it must be a transition to state 1 by in Property TR{pair} of canonically numbered BTMs,
so if the third instruction is
.CW f ,
then the BTM will terminate in just 2 steps.
Hence,
for prefixes of length 3,
those ending with
.CW f
can be excluded.
.PP
We will only need prefixes that begin with a capital letter to avoid mirrored equivalences,
and with at most one
.CW f .
A full analysis of such prefixes of length 3,
following the line of reasoning in the examples above,
gives the following 10 regexes that can be used to filter out useless prefixes:
.EQ
delim off
.EN
.KS
.TS
center,box;
cefC |cefC.
^f	^.0
_
f$	^O.*1$
_
[IO]1$	^[IO].*[IO]0$
_
^O.*o0$	^I[IOo]0[io]0$
_
^I[IiOo]o0$	^If[io]0$
.TE
.KE
.EQ
delim $$
.EN
I will omit the lengthy analysis.
If you check them one after another it should become clear why each one is there.
.PP
The saving is significant.
While the number of prefixes of length 3 that begin with a capital letter and contains at most one \fCf\fP,
as produced by
.CW "./btm\-enum -mu -l 3" ,
is 520,
filtering out those matching the regexes reduces the number to 189.
.PP
It's worth noting that,
since each prefix can be handled by a separate
.CW btm\-enum
process,
multiple asynchronous
.CW btm\-enum
processes can be deployed to significantly boost the enumeration performance on a multi-core computer.
(In fact,
parallelism rather than the avoidance of certain prefixes was my primary motivation of introducing the
.CW \-p
option to
.CW btm\-enum .)
.NH
The Toolkit:
.CW btm\-find ,
.CW btm\-cont
and
.CW btm\-mine
.IP "\(bu \ \ \fCbtm\-find\fP:"
Synopsis:
.DS
.CW
btm\-find [-es] size minrep,index duplen \\
                minrun[,maxrun] [maxtry]
.P
.DE
The
.CW btm\-find
bash script uses
.CW btm\-enum
and does basically the same thing but spawns a number of
.CW btm\-enum
processes for different prefixes to utilize multiple CPU cores.
.CW size
is the argument to
.CW btm\-enum ,
specifying the size of BTMs to be generated.
.CW minrun[,maxrun]
.CW minrun "" (
or
.CW minrun,maxrun )
is the argument to
.CW btm\-enum 's
.CW \-t
option,
limiting the range of BTMs' step count upon halt.
.CW minrep,index
and
.CW duplen
are passed to
.CW btm\-enum 's
.CW \-z
option and
.CW \-d
option,
respectively,
setting parameters of the repetition detection mechanism.
.IP
.CW btm\-find
internally runs
.CW btm\-enum
with flags
.CW \-f ,
.CW \-u
and
.CW \-s
to require exactly one FIN in every BTM's instruction table and exclude separable BTMs (as defined in section ``Minimizing Search Space'').
.CW btm\-enum 's
.CW \-a
flag is also set so that,
if
.CW maxrun
is given,
the number of steps each BTM can run is appended to each output BTM after a tab.
.IP
The
.CW \-e
option,
if specified,
is passed through to
.CW btm\-enum ,
specifying the type of generated BTMs to be nonerasing.
The
.CW \-s
option makes
.CW btm\-find
exit once a single result is output,
and is used in the
.CW btm\-mine
script.
.IP
If the optional
.CW maxtry
argument isn't given,
the enumeration is ordered,
otherwise it's passed to
.CW btm\-enum 's
.CW \-r
option for random generation,
so with a non-negative
.CW maxtry ,
at most this many random BTMs will be tried,
and a negative
.CW maxtry
means no upper bound on the numbers of trials.
.IP
The output comes from concatenating and sorting output collected from
.CW btm\-enum
processes.
So,
when
.CW maxrun
is not given,
a list of (string representations of instruction tables of) BTMs will be printed one per line,
and when
.CW maxrun
is given,
each BTM in the output is followed by a tab and the step count of the BTM,
and the lines are sorted by the step counts,
from high to low.
.IP "\(bu \ \ \fCbtm\-cont\fP:"
Synopsis:
.DS
.CW "btm\-cont file nstep"
.DE
This bash script is a high level interface of
.CW btm\-emul .
.CW file
is expected to contain a list of unfinished BTMs (instruction table plus optional configuration specification),
one per line and each in the form that can be fed to
.CW btm\-emul .
Preceding the unfinished BTMs there could be a line telling how many steps the unfinished BTMs have been run for,
in the form of
.DS
.CW "step count: [...]"
.DE
followed by zero or more such lines for finished BTMs:
.DS
.CW "[...] finished in [...] steps"
.DE
as taken from the summary lines of
.CW btm\-emul .
.IP
.CW btm\-cont
tries to read the ``step count'' line for the current step count (to be passed to
.CW btm\-emul 's
.CW \-b
option).
The count is assumed zero if that line is absent.
.CW btm\-cont
then skips to the unfinished BTMs,
splits the list into suitable pieces and pipes them to a number of asynchronous
.CW btm\-emul
processes,
with the
.CW nstep
argument passed to
.CW btm\-emul 's
.CW \-n
option to set the maxmum number of steps.
The
.CW \-s
and
.CW \-c
options are passed to
.CW btm\-emul
to control its output format,
and output of the
.CW btm\-emul
processes are collected and sorted into
.CW file ,
with the newly finished ones,
if any,
appended to the (possibly empty) list of already finished ones,
and the unfinished ones updated with new configurations.
The ``step count'' line is also updated.
.IP
The standard output of
.CW btm\-cont
is used to print newly finished BTMs.
The newly finished BTMs are sorted by their step count ascendingly.
.IP
This script can be used to batch a list of BTMs stored in a file,
which may be originally produced by using
.CW btm\-find
without a
.CW maxrun
argument.
The file is updated in place,
and can be passed to
.CW btm\-cont
again and again to continue the unfinished BTMs.
.IP "\(bu \ \ \fCbtm\-mine\fP:"
Synopsis:
.DS
.CW "btm\-mine [-e] size minrep,index duplen minrun mult dur"
.DE
This bash script is a simple wrapper of
.CW btm\-find .
The
.CW \-e
option and the
.CW size ,
.CW minrep,index
and
.CW duplen
arguments all have a simple correspondence to
.CW btm\-find 's
options and arguments.
For the
.CW minrun,maxrun
argument to
.CW btm\-find ,
.CW btm\-mine
initially uses
its
.CW minrun
argument as
.CW btm-find 's
.CW minrun ,
and $\fCminrun\fP cdot \fCmult\fP$ as
.CW btm-find 's
.CW maxrun .
.CW btm\-find
is given the
.CW "\-r \-1"
.CW \-r "" (
with a negative argument) and the
.CW \-s
options so that it performs random generation until it gives one result.
Once
.CW btm\-find
gives a result,
which necessarily attains $n >= \fCminrun\fP$ steps,
.CW btm\-mine
reruns
.CW btm\-find
but with $\fCminrun\fP = n + 1$ and $\fCmaxrun\fP = (n + 1) cdot \fCmult\fP$,
so on and so forth,
until the time duration in seconds specified by the
.CW dur
argument has passed.
.LP
The toolkit gives us flexible ways to attack the problems of finding long-running BTMs of different sizes and different types.
The next section will be an application and a demonstration.
.NH
Demonstration
.LP
The computer used to perform the tasks has 8 hyper-threading x86-64 cores,
with a base frequency of 1.7GHz and a max frequency of 4.1GHz.
The parameters are mostly tuned by running
.CW btm\-find
for random searching.
.LP
Let's start with size 5.
.IP "\(bu \ 5-state nonerasing BTM:"
I used this command first:
.DS
.CW "./btm\-find -e 5 4,10 5 50 >5e.txt"
.DE
It took half a minute to finish on my machine and produced 1,888 results.
Then it took no notable time to use
.CW btm\-cont
to emulate BTMs dumped in
.CW 5e.txt
to an accumulated 100,000 steps.
The record is
.DS
.CW "OI2i3i4fIII0Ii1 finished in 153 steps" .
.DE
.IP "\(bu \ 5-state BTM"
Other researchers have achieved remarkable results for 5-state BTM.
In 1990,
Heiner Marxen
.[
marxen
.]
found a BTM that halts after 47,176,870 steps,
and in 2024 it was proven to be the 5th Busy Beaver.
.[
bb5proof
.]
.[
bbchallenge
.]
Nevertheless,
let's use our toolkit to try to attack the problem as a demonstration.
The following command took about 8 minutes on my machine and produced 644,524 results.
.DS
.CW "./btm\-find 5 4,11 20 1000 >5.txt"
.DE
Using
.CW "btm\-cont"
multiple times,
I pushed the accumulated step count to 3 million in a combined time of 17 minutes.
The best result is
.DS
.CW "Oo2II3i0o4IfiI finished in 2358065 steps"
.DE
This is not particularly impressive compared to the result found by Marxen,
.[
marxen
.]
especially given that he used a much less powerful computer over 30 years ago.
Marxen deployed sophisticated methods of accelerating Turing machine simulation and pruning nonterminating Turing machines during simulation,
which I wasn't aware of until lately and haven't managed to use in my own programs.\**
.FS
Previously I found that the best result within the upper bound of 2 million steps is
.CW "Io2II3i0O1Ofi2I" ,
who takes 134,467 to finish.
Being unaware of the existing breakthrough for BB-5,
I thought it was a pretty good candidate for BB-5.
Through careful analysis of its behavior,
I have used it to construct a BTM of size 10,
.CW "Io2II3i0O1Oo5i2I0iI7iO8Io6I6IO5f" ,
that takes 134,040,938,752 steps to halt,
and a BTM of size 15,
.CW "Io2II3i0O1Oo5i2I0iI7iO8Io6I6IO5OiO12Io10I10IOfi10I11" ,
that takes 7,503,558,558,117,200,798 steps to halt.
.FE
.LP
The searching that comes next is for nonerasing BTMs of size 10 and 15.
For those sizes,
the number of nonerasing BTMs (see the ``BTM Counts'' section) became too large to exhaust,
so I used
.CW btm\-mine
to effectively utilize random searching.
.CW btm\-mine 's
searching can be continued after it stops by running
.CW btm\-mine
again with an updated
.CW minrun
argument.
.IP "\(bu \ 10-state and 15-state nonerasing BTM:"
For 10-state nonerasing BTM,
I ran
.CW btm\-mine
multiple times with different
.CW minrun
and
.CW dur
parameters that result in effectively running the following command:
.DS
.CW "./btm\-mine -e 10 4,12 20 100 10 43200"
.DE
After 12 hours,
the record is
.DS
.CW "Ii2O3I1o0i0i2IoIO4IOI4O2IO1iO5f 3518"
.DE
For 15-state nonerasing BTM,
I effectively ran the following command:
.DS
.CW "./btm\-mine -e 15 4,12 20 100 10 43200"
.DE
The record after 12 hours is:
.DS
.CW "OI0II0Oii2Io2ifIo1iI1Ii5iI2io6ii6io10II6iI14i4  32684"
.DE
.NH
Conclusion
.PP
With the aim of attacking the BB problem for general and nonerasing BTMs,
I developed the
.CW btm
C library,
the
.CW btm\-enum
and
.CW btm\-emul
C programs,
and a toolkit consisting of bash scripts
.CW btm\-find ,
.CW btm\-cont
and
.CW btm\-mine .
The source code is publicly available in the following Git repository:
.DS C
.CW https://github.com/juiyung/btm
.DE
.PP
An efficient enumeration algorithm,
various criteria to minimize the search space,
as well as parallelization have been implemented to boost the performance.
Currently,
the main shortcomings are a lack of acceleration of BTM simulation and insufficient pruning of nonterminating BTMs during simulation,
which haven't been addressed due to limited time.
However,
the library, programs and scripts are modular and ready for flexible adoption in further researches,
and their open-source nature allows for modification to better suit specific purposes.
