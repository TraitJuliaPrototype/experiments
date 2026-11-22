#!/usr/bin/env python3
"""E-537: the cells of time-*.log files as a table. Per cell (stack, problem, cb, form): the minimum of the processes'
minima, the range of the processes' medians, the processes, allocation and GC per solve, the counts and the error.
    python3 tables.py logs/time-a.log [logs/time-b.log ...]"""
import re, sys
from collections import OrderedDict

R = re.compile(r"^R (\S+) (\S+) (cb\d) (\S+) n=(\d+) \| min (\S+) med (\S+) ms \| alloc (\S+) MiB gc (\S+) ms per solve \| "
               r"naccept (\d+) nreject (\d+) nf (\d+) njac (\d+) nw (\d+) jaccalls (-?\d+) \| pulses (\d+) \| err (\S+)")
cells = OrderedDict()
for path in sys.argv[1:]:
    for line in open(path):
        m = R.match(line)
        if not m:
            continue
        k = m.group(2, 3, 1, 4)
        cells.setdefault(k, []).append(m)
print("| problem | cb | stack | form | min (ms) | medians (ms) | procs | alloc MiB | gc ms | accepted | rejected | nf | Jacobians | factorizations | dual calls | pulses | error |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for (prob, cb, st, fm), ms in cells.items():
    mins = [float(m[6]) for m in ms]; meds = sorted(float(m[7]) for m in ms)
    m = ms[-1]
    print(f"| {prob} n={m[5]} | {cb} | {st} | {fm} | {min(mins):.3f} | {meds[0]:.3f}–{meds[-1]:.3f} | {len(ms)} | {m[8]} | {m[9]} | "
          f"{m[10]} | {m[11]} | {m[12]} | {m[13]} | {m[14]} | {m[15] if m[15] != '-1' else 'in nf'} | {m[16]} | {m[17]} |")
