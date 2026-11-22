#!/usr/bin/env python3
"""W-170 (E-538): the cells of time-*.log files as a table (E-537's tables.py, with the setting B or A first).
Per cell (problem, cb, setting, stack, form): the minimum of the processes' minima, the range of the processes'
medians, the processes, allocation and GC per solve, the counts, the error.
    python3 tables.py logs/time-a.log [logs/time-b.log ...]"""
import re, sys
from collections import OrderedDict

R = re.compile(r"^R (\S+) (\S+) (\S+) (cb\d) (\S+) n=(\d+) \| min (\S+) med (\S+) ms \| alloc (\S+) MiB gc (\S+) ms per solve \| "
               r"naccept (\d+) nreject (\d+) nf (\d+) njac (\d+) nw (\d+) jaccalls (-?\d+) \| pulses (\d+) \| err (\S+)")
cells = OrderedDict()
for path in sys.argv[1:]:
    for line in open(path):
        m = R.match(line)
        if m:
            cells.setdefault((m[3], m[4], m[1], m[2], m[5]), []).append(m)
print("| problem | cb | setting | stack | form | min (ms) | medians (ms) | procs | alloc MiB | gc ms | accepted | rejected | nf | dual calls | pulses | error |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for (prob, cb, s, st, fm), ms in sorted(cells.items(), key=lambda kv: (kv[0][0], kv[0][1], kv[0][3] == "plain", kv[0][2] == "A", kv[0][4])):
    mins = [float(m[7]) for m in ms]; meds = sorted(float(m[8]) for m in ms)
    m = ms[-1]
    print(f"| {prob} n={m[6]} | {cb} | {s} | {st} | {fm} | {min(mins):.3f} | {meds[0]:.3f}–{meds[-1]:.3f} | {len(ms)} | {m[9]} | {m[10]} | "
          f"{m[11]} | {m[12]} | {m[13]} | {m[16]} | {m[17]} | {m[18]} |")
