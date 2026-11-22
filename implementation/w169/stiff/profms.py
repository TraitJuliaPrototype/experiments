#!/usr/bin/env python3
"""E-537: a profile log's classes in ms per solve (samples per solve x share x the 0.5 ms interval), one column per
cell, per problem; the dispatch part of each class in brackets.
    python3 profms.py logs/prof-r1.log    (or logs/nd-prof-r2.log)"""
import re, sys
from collections import OrderedDict

HEAD = re.compile(r"^P (.+?) \| samples in solves (\d+) \| solves (\d+) \| samples per solve ([\d.]+)")
ROW = re.compile(r"^P (.+?) \| (.+?) \| ([\d.]+) \| ([\d.]+) \| ([\d.]+) \| ([\d.]+) \| ([\d.]+) \| ([\d.]+)$")
sps = {}; rows = OrderedDict()
for line in open(sys.argv[1]):
    line = line.rstrip("\n")
    m = HEAD.match(line)
    if m:
        sps[m[1]] = float(m[4]); continue
    m = ROW.match(line)
    if m and m[2] not in ("context", "all"):
        rows.setdefault(m[1], OrderedDict())[m[2]] = (float(m[3]), float(m[6]))
groups = OrderedDict()
for cell in rows:
    key = " ".join(w for w in cell.split() if not w.startswith(("box", "compiled", "wrap", "spec", "port", "plain", "upstream", "api")))
    groups.setdefault(key, []).append(cell)
for key, cells in groups.items():
    classes = []
    for c in cells:
        for k in rows[c]:
            if k not in classes:
                classes.append(k)
    print(f"\n{key}: ms per solve (of it dispatch at run time)\n")
    print("| class | " + " | ".join(c.replace(key, "").strip() or c for c in cells) + " |")
    print("|---|" + "---|" * len(cells))
    for k in classes:
        vals = []
        for c in cells:
            a, d = rows[c].get(k, (0.0, 0.0))
            vals.append(f"{sps[c] * a / 100 * 0.5:.3f} ({sps[c] * d / 100 * 0.5:.3f})")
        print(f"| {k} | " + " | ".join(vals) + " |")
    print("| all | " + " | ".join(f"{sps[c] * 0.5:.3f}" for c in cells) + " |")
