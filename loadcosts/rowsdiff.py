#!/usr/bin/env python3
"""rows.jl run with --trace-compile=stderr --trace-compile-timing, stdout and stderr through one
pipe (run_rows_traced.sh). A trace entry belongs to the row whose output line it precedes.
Entries of the printing itself (print, println, round on a pipe) are dropped.
Per row: its time, the trace entries the run has and the reference has not, their sum, the rest.
    python3 rowsdiff.py <ref.log> <run.log> [--all]"""
import re, sys
from collections import defaultdict, OrderedDict
ansi = re.compile(r'\x1b\[[0-9;]*m')
ent = re.compile(r'#=\s*([0-9.]+) ms =# precompile\((.*?)\)( # recompile)?\n')
rowre = re.compile(r'^row (\d+) (.*?) ([0-9.]+) ms(?:, gc [0-9.]+ ms)?$')
PRINT = ('typeof(Base.print)', 'typeof(Base.println)', 'typeof(Base.round)', 'PipeEndpoint')
def parse(p):
    text = ansi.sub('', open(p, errors='replace').read())
    out = []; ents = []; pos = 0
    for m in ent.finditer(text):
        out.append(text[pos:m.start()]); pos = m.end()
        ents.append((sum(len(s) for s in out), float(m.group(1)), m.group(2), bool(m.group(3))))
    out.append(text[pos:]); stdout = ''.join(out)
    rows = OrderedDict(); start = 0; i = 0
    for line in stdout.split('\n'):
        end = start + len(line) + 1
        mine = []
        while i < len(ents) and ents[i][0] < end:
            if not any(s in ents[i][2] for s in PRINT): mine.append(ents[i][1:])
            i += 1
        r = rowre.match(line.strip())
        if r: rows[r.group(1) + ' ' + r.group(2)] = (float(r.group(3)), mine)
        start = end
    return rows
ref, run = parse(sys.argv[1]), parse(sys.argv[2])
for k, (t, ents) in run.items():
    if k not in ref: continue
    t0, e0 = ref[k]
    refs = defaultdict(float)
    for ms, s, _ in e0: refs[s] += ms
    extra = [(ms, s, rc) for ms, s, rc in ents if s not in refs]
    ex = sum(e[0] for e in extra)
    print(f"row {k}: {t:.1f} ms against {t0:.1f} ({t - t0:+.1f}); trace entries only in the run {ex:.1f} ms; rest {t - t0 - ex:+.1f}")
    for ms, s, rc in sorted(extra, reverse=True)[:6]:
        print(f"      {ms:6.1f}  {'recompile ' if rc else ''}{s[:200]}")
    if '--all' in sys.argv:
        for ms, s, rc in ents: print(f"         [{ms:6.1f}{' rc' if rc else ''}] {s[:160]}")
