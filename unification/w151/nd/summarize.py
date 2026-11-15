#!/usr/bin/env python3
"""E-403's table: per log, the session, the first pass, the steady state (`again` d), new equations (`changed` b-e, E-310's
row), `graphtype`, and whether the digests equal the first log's.   summarize.py logs/<name>-*.log"""
import sys, re
rows = []; ref = None
for f in sys.argv[1:]:
    T = {}; D = []; sess = wt = None
    for l in open(f):
        m = re.match(r"T (\w+) (\w) ([\d.]+) compile ([\d.]+)", l)
        if m: T[(m[1], m[2])] = (float(m[3]), float(m[4]))
        if l.startswith("D "): D.append(l.strip())
        m = re.search(r"# rc=\d+ session ([\d.]+)", l)
        if m: sess = float(m[1])
    if not T or sess is None: continue
    if ref is None: ref = D
    s = lambda p, steps: sum(T.get((p, k), (0, 0))[0] for k in steps)
    rows.append((f.split("/")[-1], sess, s("first", "abcdefg") / 1000, T.get(("again", "d"), (0,))[0],
                 s("changed", "bcde"), s("graphtype", "abcdefg") / 1000, "same" if D == ref else "DIFFER", len(D)))
print("| log | session s | first s | again d ms | changed b-e ms | graphtype s | digests |")
print("|---|---|---|---|---|---|---|")
for r in rows:
    print(f"| {r[0]} | {r[1]:.1f} | {r[2]:.2f} | {r[3]:.1f} | {r[4]:.1f} | {r[5]:.2f} | {r[6]} ({r[7]}) |")
