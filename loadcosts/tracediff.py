#!/usr/bin/env python3
"""Per row of tde_diag.jl's compile trace: the entries (dispatch roots compiled, with their time)
that a run has and a reference run has not, and their sum.
    python3 tracediff.py <ref.trace> <run.trace> [row ...]"""
import re, sys
from collections import defaultdict
ansi = re.compile(r'\x1b\[[0-9;]*m')
ent = re.compile(r'#=\s*([0-9.]+) ms =# precompile\((.*)\)( # recompile)?$')
SKIP = ('Main.post', 'Main.var"#tally', 'Main.var"#post', 'Main.rec', 'NamedTuple{(:time, :compile_time', 'Base.RefValue{Any}')
def parse(p):
    rows = defaultdict(list); cur = None
    for line in open(p, errors='replace'):
        line = ansi.sub('', line.rstrip('\n'))
        if line.startswith('#### row'):
            cur = line[5:]; continue
        m = ent.match(line)
        if m and cur:
            sig = m.group(2)
            if any(s in sig for s in SKIP): continue
            rows[cur].append((float(m.group(1)), sig, bool(m.group(3))))
    return rows
ref, run = parse(sys.argv[1]), parse(sys.argv[2])
want = sys.argv[3:]
for r in run:
    if want and not any(r.startswith('row ' + w + ' ') for w in want): continue
    refsigs = defaultdict(float)
    for ms, s, _ in ref.get(r, []): refsigs[s] += ms
    extra = [(ms, s, rc) for ms, s, rc in run[r] if s not in refsigs]
    tot_run = sum(ms for ms, _, _ in run[r]); tot_ref = sum(ms for ms, _, _ in ref.get(r, []))
    print(f"{r}: trace total {tot_run:.1f} ms (ref {tot_ref:.1f}); only in run: {sum(e[0] for e in extra):.1f} ms in {len(extra)} entries")
    for ms, s, rc in sorted(extra, reverse=True)[:12]:
        print(f"    {ms:7.1f}  {'recompile ' if rc else ''}{s[:220]}")
