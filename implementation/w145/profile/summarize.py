#!/usr/bin/env python3
# E-388: each phase's unprofiled time, split by the profile's shares (classes of 5 % or more). -> stdout (markdown)
import re, sys
def parse(f):
    t = {}; sh = {}; cur = None; head = ""
    for l in open(f):
        if l.startswith("# E-388"): head = l.strip()
        m = re.match(r"## (.*): ([\d.]+) ms unprofiled", l)
        if m: t[m.group(1)] = float(m.group(2)); continue
        m = re.match(r"## (.*): ([\d.]+) ms, (\d+) samples", l)
        if m: cur = m.group(1); sh[cur] = {}; continue
        m = re.match(r"  (.{46})\s*([\d.]+) %", l)
        if m and cur: sh[cur][m.group(1).strip()] = float(m.group(2))
    return head, t, sh
for f in sys.argv[1:]:
    head, t, sh = parse(f)
    print("### %s\n\n`%s`\n\n| Phase | Time | Where it goes (ms) |\n|---|---|---|" % (f.split("/")[-1][:-4], head[2:]))
    for ph in t:
        parts = ["%s %.0f" % (c, t[ph] * p / 100) for c, p in sorted(sh.get(ph, {}).items(), key=lambda x: -x[1]) if p >= 5]
        print("| %s | %.0f ms | %s |" % (ph, t[ph], "; ".join(parts)))
    print()
