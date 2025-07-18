Typing `make` (assuming the command is available) in the project directory
will compile the `btm-enum` and `btm-emul` C programs.  Tested with
`gcc` \+ glibc and `gcc` \+ musl libc.  The `-h` option can be passed
to either C program to show its usage.

The `btm-find`, `btm-cont` and `btm-mine` bash scripts depend on GNU
coreutils.  The `-h` option can be passed to any of the scripts for a
short reminder of its usage.

Documentation of the btm library\'s API can be found in `btm.h`.

There is a report that can be built by changing into the `doc`
subdirectory and typing `make`.  The compilation depends on `groff`,
`eqn`, `tbl`, `refer`, `awk` and the -ms macro package and produces
`report.pdf`.  Check the report for more information.
