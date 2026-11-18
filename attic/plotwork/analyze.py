# Reads logs/run.log; per order, size and mode: the session's fixed cost, the steady round, the
# break-even number of rounds. Model: a session of N rounds costs F + N*s; F is the wall time of the
# fresh process minus REPS steady rounds, s the median round of reps 3..REPS (no compilation).
import sys, re, statistics as st
from collections import defaultdict
log = sys.argv[1] if len(sys.argv) > 1 else "logs/run.log"
rows = defaultdict(list); walls = defaultdict(list); cur = None
for line in open(log):
    m = re.match(r"== (\S+) (\S+) (\S+) run (\d+)", line)
    if m: cur = (m[2], m[3], m[1], int(m[4])); continue
    if line.startswith("ROW"):
        _, mode, phase, i, t, c, rc, b = line.split()
        rows[cur].append((phase, int(i), float(t), float(c), float(rc), int(b)))
    elif line.startswith("WALL"):
        walls[cur].append(float(line.split()[-1]) * 1e3)
PH = ["read", "plot", "render", "edit", "render-edited", "edit10"]
res = defaultdict(dict)
for key, rs in rows.items():
    order, size, mode, run = key
    reps = max(i for _, i, *_ in rs)
    rounds = defaultdict(float); per = defaultdict(list)
    for ph, i, t, c, rc, b in rs:
        if ph in PH and i >= 1: rounds[i] += t
        if ph in PH and i >= 3: per[ph].append(t)
    s = st.median(rounds[i] for i in range(3, reps + 1))
    first = sum(t for ph, i, t, *_ in rs if i <= 1 or ph.startswith("load"))
    comp = sum(c for ph, i, t, c, *_ in rs); rcomp = sum(rc for ph, i, t, c, rc, b in rs)
    wall = walls[key][0]
    res[(order, size, mode)][run] = dict(s=s, F=wall - reps * s, wall=wall, first=first, comp=comp, rcomp=rcomp,
                                         per={ph: st.median(v) for ph, v in per.items()})
def med(xs): return st.median(xs)
print(f"{'order':12} {'size':5} {'mode':5} {'wall':>8} {'F':>8} {'compile':>8} {'recomp':>7} {'round':>7}  read  plot render  edit r-edit edit10")
for (order, size, mode), runs in sorted(res.items()):
    v = list(runs.values())
    per = {ph: med([r["per"][ph] for r in v]) for ph in PH}
    print(f"{order:12} {size:5} {mode:5} {med([r['wall'] for r in v]):8.0f} {med([r['F'] for r in v]):8.0f} "
          f"{med([r['comp'] for r in v]):8.0f} {med([r['rcomp'] for r in v]):7.0f} {med([r['s'] for r in v]):7.1f}  "
          + " ".join(f"{per[ph]:5.1f}" for ph in PH) + f"   (runs {len(v)}; rounds per run {[round(r['s']) for r in v]})")
print()
for order, size in sorted({(o, s) for o, s, _ in res}):
    p = res.get((order, size, "plain")); a = res.get((order, size, "all"))
    if not p or not a: continue
    Fp = med([r["F"] for r in p.values()]); Fa = med([r["F"] for r in a.values()])
    sp = med([r["s"] for r in p.values()]); sa = med([r["s"] for r in a.values()])
    ep = med([r["per"]["edit10"] for r in p.values()]) / 10; ea = med([r["per"]["edit10"] for r in a.values()]) / 10
    print(f"{order:12} {size:5}: fixed cost saved by all {Fp - Fa:7.0f} ms; a round costs {sa - sp:+6.1f} ms under all "
          f"({sa / sp:.2f}x); break-even {((Fp - Fa) / (sa - sp)) if sa > sp else float('inf'):6.0f} rounds"
          f"; or {((Fp - Fa) / (ea - ep)) if ea > ep else float('inf'):6.0f} edits without rendering ({ea:.2f} vs {ep:.2f} ms per edit)")
