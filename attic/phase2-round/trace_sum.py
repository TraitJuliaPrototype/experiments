"""E-233: the compile roots of a --trace-compile-timing trace, between the probe marks (rec.jl's `_snap!` and
TraitWorld's `loadreport`), by kind. Roots' times include their callees' compilation.
    python3 -I trace_sum.py <trace.jl>"""
import re, sys, collections
rows = []
for i, l in enumerate(open(sys.argv[1]).read().splitlines()):
    m = re.match(r"#= *([0-9.]+) ms =# (.*)", l)
    if m: rows.append((i, float(m.group(1)), m.group(2)))
lo = [i for i, t, s in rows if '_snap!' in s][0]
hi = [i for i, t, s in rows if 'loadreport' in s and 'switch' not in s][0]
pre = [r for r in rows if r[0] < lo]; ses = [r for r in rows if lo < r[0] < hi and 'Main.var"#_' not in r[2] and 'Main._' not in r[2]]
print("before the load mark (start, imports):", len(pre), "roots", round(sum(r[1] for r in pre)), "ms; of it recompiled (invalidated)",
      round(sum(r[1] for r in pre if '# recompile' in r[2])), "ms")
def cat(s):
    if '# recompile' in s: return 'recompiled (invalidated by the loads)'
    if 'TraitWorld' in s or 'ColumnCore' in s or 'Compiler.' in s: return "TraitWorld's Callable/checks, byrow, inference"
    if 'REPL' in s or 'show' in s or 'print' in s or 'PrettyTables' in s or 'Terminals' in s: return 'display (REPL, show)'
    if 'Main.' in s: return "the user's closures"
    if 'DataFrames' in s or 'CSV' in s or 'Tables' in s or 'DataStrings' in s: return 'DataFrames, CSV, Tables (plain)'
    return 'Base, other'
c = collections.defaultdict(lambda: [0, 0.0])
for i, t, s in ses: k = cat(s); c[k][0] += 1; c[k][1] += t
print("after the load mark (the steps):", len(ses), "roots", round(sum(r[1] for r in ses)), "ms")
for k, (n, t) in sorted(c.items(), key=lambda x: -x[1][1]): print(f"  {k:45s} {n:4d} roots {t:7.0f} ms")
