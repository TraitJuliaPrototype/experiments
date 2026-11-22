#!/usr/bin/env python3
"""W-170 (E-538): the session cells' phases (load, first run, second run; compile), median and range over the rounds
1..P (round 0, the warm-up, left out).
    python3 sesstab.py logs/sessions/<label>"""
import glob, re, statistics, sys
from collections import defaultdict
cells = defaultdict(lambda: defaultdict(list))
for f in sorted(glob.glob(sys.argv[1] + "-*-time-*.out")):
    m = re.search(r"-([a-z-]+)-([ABCD])-time-(\d+)\.out$", f)
    if not m or m[3] == "0": continue
    for l in open(f):
        p = l.rstrip("\n").split("\t")
        if p[0] == "P":
            cells[(m[1], m[2])][p[1]].append((float(p[2]), float(p[3].split()[1])))
print("| session | setting | runs | load (ms) | first run (ms) | of it compiling | second run (ms) |")
print("|---|---|---|---|---|---|---|")
for (ses, s), ph in sorted(cells.items()):
    def fm(k, j=0):
        v = [x[j] for x in ph.get(k, [])]
        return f"{statistics.median(v):.1f} ({min(v):.1f}–{max(v):.1f})" if v else "—"
    print(f"| {ses} | {s} | {len(ph['load'])} | {fm('load')} | {fm('first run')} | {fm('first run', 1)} | {fm('second run')} |")
