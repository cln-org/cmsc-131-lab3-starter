<!--no-pdf-->
# CMSC 131 Lab 3 Starter

[![lab3-checks](https://github.com/WhiteLicorice/cmsc-131-lab3-starter/actions/workflows/test.yml/badge.svg)](https://github.com/WhiteLicorice/cmsc-131-lab3-starter/actions/workflows/test.yml)

A grep clone whose correctness is agreement with `grep` itself, byte for byte. The manual is the assignment. This file is the repository's own notes.

## Layout

```text
Makefile            platform preamble and build rules
driver.c            provided: file reading, the line loop, and output
cdecl.h             provided: the cdecl macros for the C boundary
args.asm            yours
match.asm           yours
lines.asm           yours
fmt.asm             yours
run_tests.sh        provided: the correctness gate
contract_test.c     provided: the second pass, in C
contract_regs.asm   provided: register checks for contract_test
LICENSE             provided: the repository licence
tests/              provided: the test corpus
```

## What to Run

On Windows, run these commands in Git Bash, the shell from Block 1. In that
shell, `make` is your alias for `mingw32-make`. On Linux, use
your terminal.

```bash
make
make check
```

`make` builds `rengrep` and `contract_test`. `make check` builds both, then
runs `./run_tests.sh`, which reports each test and exits nonzero when any
of them differ.

The first `make check` takes the longest, often more than a minute on
Windows. It saves the output of your installed `grep` in `.grep-cache`, and
later runs read that saved output. A change to your `grep`, `run_tests.sh`,
or a test file makes the next run save the output again.

The gate has two passes. The first runs your tool and `grep` with the same
arguments and compares the two outputs byte for byte. It does that across
all 32 flag subsets, 7 patterns, and 6 files: 1344 comparisons. The second
is `contract_test`. It calls the four routines directly. It checks the
capacity argument, the boundary rules, the formatter, the parser, and the
register discipline. Both passes run every time, because each one catches
what the other cannot.

## Reading a First Run

The assembly files ship as stubs that assemble and link as-is, so the build
works before you write any code. Right now the parser stub exits 2 for
every command. The gate requires exit 0 for a valid invocation, so all
1345 checks fail. That red run is the correct starting state for a starter.
Expect the first passing cells once `args.asm` and `lines.asm` are in
place, and the badge turns green when the matching and formatting routines
are done.

The provided files are fixtures. The grader compares your fork against the
starter. An edit to `driver.c`, `Makefile`, `run_tests.sh`, or a `tests/`
file appears as a diff in the open.

## Documentation

The three sections at the end of this file are yours. Complete Design Notes
and Subsystem Ownership before the Week 1 progress report. Complete Quirks
and Issues before the Week 3 progress report. Each section says what it
needs. Leave the rest of this file as it is.

---

## Design Notes

- **`line_matches` (`match.asm`):** 
line_matches receives a line `(line)`, its length `(linelen)`, a pattern `(pat)`, its length `(patlen)`, and the -i and -w settings. It scans each possible position in the line and compares the pattern with the line using repe cmpsb. For -i, it compares lowercase values without changing the original text. For -w, it checks the characters before and after the match. It returns 1 for a valid match and 0 otherwise, while preserving the required registers

### Problem analysis

The five flags and what each one does. What the oracle is, and what
agreement with it means for a line that matches inside a longer word.

The five flags and what they do:
- `-n`: prefix each matching line with its 1-based line number and a colon
- `-c`: print only the count of matching lines (overrides all other output, so `-n -c` prints just the count)
- `-v`: print the lines that do not match (with `-c`, count those instead)
- `-i`: ignore upper/lower case, but still print the line as it appeared
- `-w`: match whole words only

Note: No flag just prints the matching lines.

The oracle for this laboratory is `grep`, run as `LC_ALL=C grep -F`, a command that searches a file for lines containing some text that is already installed in our machine. `make check` runs 1344 comparisons against it, and correctness just means byte-identical output. Because `rengrep` is a tool subset of `grep -F`, both of them treats the pattern as a literal substring, not a word. So `cat` matches `concatenate`,and agreeing with `grep` means `rengrep` should print that line, unless checked with a `-w` flag, of which case the whole-word boundary check around that exact literal string is applied.

### Solution architecture

The program is the provided C driver plus four cdecl assembly routines. Arguments start at `[ebp+8]`, results return in `eax`, and `ebx`, `esi`, `edi`, and `ebp` are preserved. Every routine that uses string instructions runs `cld` first, since the direction flag persists across calls.

- **`parse_args` (`args.asm`):** 
Walks `argv`. A token starting with `-` and longer than one character is a flag group. Each letter is looked up in the table `n c v i w` with `repne scasb`, and the bit is set at index `4 - ecx`. Other tokens are positional (pattern, then path). An unknown flag, a missing positional, or a third positional is an error return.

- **`index_lines` (`lines.asm`):** 
One pass over the buffer, scanning for `0x0A`. Each line's start and length (newline excluded) is stored in the output array. A final line with no newline is still recorded, an empty buffer returns 0, and writing stops at `max`.

- **`line_matches` (`match.asm`):** 
Tries each start offset from 0 to `linelen - patlen`, using signed jumps so an over-long pattern skips the loop. Without `-i`, `repe cmpsb` compares the bytes. With `-i`, a separate loop folds `A`-`Z` in registers only, never writing to the buffer. Both paths share the same candidate loop and the same `-w` boundary check. A failed boundary check keeps scanning. An empty pattern uses `test ecx, ecx` to set ZF first.

- **`int_to_dec` (`fmt.asm`):** 
Divides by 10 in a bottom-tested loop (so 0 gives `'0'`), pushes each remainder, then pops them into the output buffer. Returns the digit count.

**Flow:** `parse_args` once at startup, `index_lines` once per file, `line_matches` once per line, and `int_to_dec` whenever `-n` or `-c` needs a number. The routines only communicate through the driver, so each can be tested alone with `contract_test`.


### Timeline

One line per week. Name the subsystem each week finishes and the member
who owns it.

| Week | Goal | Owner |
|---|---|---|
| 1 | Buffering and lines, flags (`args.asm`, `lines.asm`) | Ryona Cassandra P. Honrado |
| 2 | Matching (`match.asm`) | Jhon Chriztopher Nice, Erine Lourdes Medalla |
| 3 | Formatting and additional tests (`fmt.asm`) | Adrienne Nicole Tipon |
| 4 | Defense | All Members |

## Subsystem Ownership

Complete this section before the Week 1 progress report. The manual lists
the three subsystems. Each member owns one. In a group of four, two members
share one. The commit history must agree with this table.

| Subsystem | Owner |
|---|---|
| Buffering and lines (`lines.asm`) | Ryona Cassandra P. Honrado |
| Matching (`match.asm`) | Jhon Chriztopher Nice, Erine Lourdes Medalla |
| Formatting and flags (`fmt.asm`, `args.asm`, the tests you add) | Ryona Cassandra P. Honrado & Adrienne Nicole Tipon |

## Quirks and Issues

Complete this section before the Week 3 progress report. The syllabus asks
for documentation of quirks and issues with the complete implementation.
One entry per item. State what happens, what causes it, and what the group
did about it.

### Known issues

- 

### Quirks

- 
