# Tabulates rows.jl logs (run_rows_whole.sh): per row and load order, the runs of each log.
# Usage: python3 rowscompare.py [--nogc] logs/rowswhole-A.log logs/rowswhole-B.log   (--nogc: the garbage collector's time subtracted)
import sys, re
NOGC = '--nogc' in sys.argv; sys.argv = [a for a in sys.argv if a != '--nogc']
from collections import defaultdict, OrderedDict
def read(p):
    d = defaultdict(list); order = None; names = OrderedDict()
    for l in open(p):
        m = re.match(r"-- rows (\w+) run", l)
        if m: order = m[1]; continue
        m = re.match(r"(row \d .*?) ([\d.]+) ms(?:, gc ([\d.]+) ms)?$", l.strip())
        if m: d[(m[1], order)].append(float(m[2]) - (float(m[3]) if (m[3] and NOGC) else 0.0)); names[m[1]] = 1
        m = re.match(r"(using TraitDifferentialEquations|loads) ([\d.]+) s$", l.strip())
        if m: d[(m[1], order)].append(1000 * float(m[2])); names[m[1]] = 1
    return d, names
logs = [read(p) for p in sys.argv[1:]]
names = OrderedDict((k, 1) for _, n in logs for k in n)
fmt = lambda v: "–".join(f"{x:.0f}" for x in sorted(v)) if v else "—"
print("| Row | " + " | ".join(f"{o} ({i + 1})" for o in ("none", "before", "after") for i in range(len(logs))) + " |")
print("|---|" + "---|" * (3 * len(logs)))
for n in names:
    print(f"| {n} | " + " | ".join(fmt(logs[i][0].get((n, o), [])) for o in ("none", "before", "after") for i in range(len(logs))) + " |")
