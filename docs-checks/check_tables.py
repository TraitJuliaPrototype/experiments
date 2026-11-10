"""The record's tables: every row has its table's number of cells.

A report: it changes nothing. One line per row whose cell count differs from its table's header,
`file:line: n cells, the header has m: <ID>`; the count on stderr. A `|` inside a code span does not
split a cell, nor an escaped `\\|`.

Usage, from the design repository's root:
    python3 -I experiments/docs-checks/check_tables.py writeup/record/experiments.md [more files…]
"""
import re, sys

def cells(line):
    t = re.sub(r"`[^`]*`", "X", line.rstrip("\n"))
    t = t.replace("\\|", "X")
    return len(t.split("|")) - 2          # the leading and trailing pipes

def check(path):
    bad = 0
    header = None
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()
    for i, l in enumerate(lines, 1):
        if not l.startswith("|"):
            header = None
            continue
        if header is None:
            header = cells(l)
            continue
        if re.match(r"^\|\s*:?-{3,}", l):
            continue
        n = cells(l)
        if n != header:
            bad += 1
            ident = l.split("|")[1].strip()[:20]
            print(f"{path}:{i}: {n} cells, the header has {header}: {ident}")
    return bad

total = sum(check(p) for p in sys.argv[1:])
print(f"{total} rows", file=sys.stderr)
