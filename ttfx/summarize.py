# E-168: per step, the wall time since the previous mark (the first from before exec), and for Julia
# the compile and GC time within it.   python3 -I summarize.py logs/<tag>/*.log
import sys
for path in sys.argv[1:]:
    W = E = None; marks = []; bad = []
    for line in open(path):
        if "Precompiling" in line or "Rejecting cache" in line or "ERROR" in line or line.startswith("STALE ") or line.startswith("rc=") and line.strip() != "rc=0":
            bad.append(line.strip()[:60])
        p = line.split()
        if not p: continue
        if p[0] == "W": W = float(p[1])
        elif p[0] == "E": E = float(p[1])
        elif p[0] == "T" and len(p) >= 3:
            marks.append((p[1], float(p[2]), float(p[3]) if len(p) > 3 else 0.0, float(p[4]) if len(p) > 4 else 0.0))
    if W is None or not marks: print(path, "incomplete"); continue
    prev, pc, pg, cells = W, 0.0, 0.0, []
    for step, t, c, g in marks:
        name = "startup" if step == "start" else step
        cells.append(f"{name} {t-prev:.3f}" + (f" (c {c-pc:.2f}, gc {g-pg:.2f})" if c or g else ""))
        prev, pc, pg = t, c, g
    if E is not None: cells.append(f"exit {E-prev:.3f}")
    again = [t for step, t, c, g in marks if step == "again"]
    sess = f"| session (to again) {again[0]-W:.3f}" if again else ""
    print(path, "|", " | ".join(cells), "| total", f"{(E or prev)-W:.3f}", sess, ("| INVALID: " + "; ".join(bad[:2])) if bad else "")
