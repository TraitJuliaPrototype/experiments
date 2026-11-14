#!/usr/bin/env python3
# W-145, part 2: a table from run.sh's logs: python3 summarize.py logs/cache.log [more logs…] (a later log replaces a case)
import re, sys, collections
runs = collections.OrderedDict(); classes = {}
for f in sys.argv[1:]:
    seen = set()
    for l in open(f):
        m = re.match(r"(\S+) run \d+: wall \S+ s \| load (\S+) ms \| body (\S+) ms \| first run (\S+) ms, of it compiling (\S+) ms \| second run (\S+) ms", l)
        if m:
            d = m.group(1)
            if d not in seen: runs[d] = []; classes[d] = {}; seen.add(d)
            runs[d].append([float(x) for x in m.groups()[1:]])
        m = re.match(r"(\S+) class (.*) \| (\d+) \| (\S+) \| (\S+)$", l)
        if m: classes[m.group(1)][m.group(2)] = (int(m.group(3)), float(m.group(4)), float(m.group(5)))
order = ["A's method at B's type", "A's method, other", "B's method", "the glue's method", "the session's own", "TraitWorld's", "Julia's method at B's type", "Julia's own"]
rng = lambda xs: ("%.0f" % min(xs)) if max(xs) - min(xs) < 0.6 else "%.0f–%.0f" % (min(xs), max(xs))
print("| Case | Load, ms | Session's definitions, ms | First run, ms | Second run, ms | " + " | ".join(order) + " |")
print("|---|---|---|---|---|" + "---|" * len(order))
for d, rs in runs.items():
    cols = list(zip(*rs))
    cl = classes[d]
    cells = [("%d: %.0f + %.0f" % cl[k]) if k in cl else "—" for k in order]
    print("| %s | %s | %s | %s | %s | %s |" % (d, rng(cols[0]), rng(cols[1]), rng(cols[2]), ("%.1f" % min(cols[4])), " | ".join(cells)))
print("\nA class's cell: instances made after the loads: their own inference ms + their code generation ms (the last run).")
