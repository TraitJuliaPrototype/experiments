"""E-233: one line per REPL run of session.sh: each step's wall time / Julia's compile time in it (seconds;
the counter sums over threads, so it can exceed the wall time when the REPL compiles in the background); the
garbage collector's time in the totals (and per step with --table).
    python3 -I parse.py <run.out> [--table]
Marks are "T <step> <time> <compile>"; the run's start and end "S <t> E <t>" are the harness's clock. The
probe segments ("probe", "end": instrumentation between marks) are left out of the totals. "start" is from
before the process to the first mark (process start and the REPL's own start); "exit" from the last mark to
the process' end. Totals: "steps" are the marks from read to the end (the session without start and imports)."""
import re, sys
txt = open(sys.argv[1], errors="replace").read().replace("\r", "")
marks = [(m.group(1), float(m.group(2)), float(m.group(3)), float(m.group(4) or 0))
         for m in re.finditer(r"(?:^|(?<=\x1b\[0m))T ([0-9a-z_]+) ([0-9.e+]+) ([0-9.e+]+)(?: ([0-9.e+]+))?\s*$", txt, re.M)]
se = re.search(r"(?:^|(?<=\x1b\[0m))S ([0-9.]+) E ([0-9.]+)", txt, re.M)
if not marks or not se:
    print("no marks"); sys.exit()
s, e = float(se.group(1)), float(se.group(2))
rows = [("start", marks[0][1] - s, marks[0][2], marks[0][3])]
for (n0, t0, c0, g0), (n, t, c, g) in zip(marks, marks[1:]):
    rows.append((n, t - t0, c - c0, g - g0))
rows.append(("exit", e - marks[-1][1], float("nan"), float("nan")))
skip = {"probe", "end"}
steps = [r for r in rows if r[0] not in skip | {"start", "imports", "exit"}]
tot = (sum(r[1] for r in steps), sum(r[2] for r in steps), sum(r[3] for r in steps))
wall = e - s - sum(r[1] for r in rows if r[0] in skip)
if "--table" in sys.argv:
    print(f"{'step':20s} {'wall':>7s} {'compile':>7s} {'gc':>7s}")
    for n, w, c, g in rows:
        print(f"{n:20s} {w:7.3f} {c:7.3f} {g:7.3f}")
    print(f"{'steps':20s} {tot[0]:7.3f} {tot[1]:7.3f} {tot[2]:7.3f}")
    print(f"{'wall (no probes)':20s} {wall:7.3f}")
else:
    print(" | ".join(f"{n} {w:.3f}/{c:.3f}" for n, w, c, g in rows if n not in skip)
          + f" | steps {tot[0]:.3f}/{tot[1]:.3f}/gc {tot[2]:.3f} | wall {wall:.3f}")
