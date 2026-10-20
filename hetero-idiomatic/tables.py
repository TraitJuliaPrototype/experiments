# Prints the README's tables from the logs of runs given as arguments (python3 tables.py r2 r3):
# per row the median ns per element of each run, product and all, and the allocation of the first.
import re, sys
runs = sys.argv[1:] or ["r2", "r3"]
pat = re.compile(r"^(product|all)\s+(\S+)\s+(.*?)\s+([\d.]+) ns/elt\s+([\d.]+) B/elt")
def rows(script, setting, run):
    out, section = [], None
    for line in open(f"logs/{run}-{script}-{setting}.log"):
        if line.startswith("-- "):
            section = line[3:].strip()
            continue
        m = pat.match(line)
        if m:
            out.append((section, m.group(2), m.group(3).strip(), float(m.group(4)), float(m.group(5))))
    return out
for script in ("hi1_cells", "hi2_shapes"):
    data = {(s, r): rows(script, s, r) for s in ("product", "all") for r in runs}
    base = data[("product", runs[0])]
    print(f"\n### {script}\n")
    print("| Workload | Kind | Code | product, ns/elt (" + ", ".join(runs) + ") | B/elt | all, ns/elt (" + ", ".join(runs) + ") | B/elt |")
    print("|---|---|---|---|---|---|---|")
    for i, (sec, kind, label, _, _) in enumerate(base):
        p = " / ".join(f"{data[('product', r)][i][3]:.2f}" for r in runs)
        a = " / ".join(f"{data[('all', r)][i][3]:.2f}" for r in runs)
        print(f"| {sec} | {kind} | {label} | {p} | {data[('product', runs[0])][i][4]:.1f} | {a} | {data[('all', runs[0])][i][4]:.1f} |")
