#!/usr/bin/env python3
"""W-169 (E-536): the split of a session's wall time, from profile.sh's runs.

    split.py <logdir> <session>-<S> [<session>-<S> ...]       -> markdown on stdout

For each cell: the unprofiled runs (`time`, every run but run 0, the warm-up) give the wall time, Julia's start (from
the process's exec to the script's first line), the exit, and each phase's median time with Julia's counters. The
profiled run (`prof`) gives each phase's shares by class; a class's time is the phase's unprofiled median times its
share (shares, not the profiled times: the profiler slows a phase). The harness's own time (the script's set-up, the
`_` phases, the profiler's first use) is what the phases leave of the script's time.
"""
import sys; sys.dont_write_bytecode = True
import glob, re, statistics as st, sys
from collections import OrderedDict, defaultdict

def med(xs):
    return st.median(xs) if xs else float("nan")

def read_time(path):
    ph = OrderedDict(); start = end = t0 = t1 = None
    for l in open(path):
        if l.startswith("START "): start = float(l.split()[1])
        elif l.startswith("END "): end = float(l.split()[1])
        elif l.startswith("WALL "): _, t0, t1 = l.split()[:3]; t0 = float(t0); t1 = float(t1)
        elif l.startswith("P\t"):
            f = l.rstrip("\n").split("\t")
            d = {"ms": float(f[2])}
            for kv in f[3:]:
                k, v = kv.split(" ", 1); d[k] = float(v)
            ph[f[1]] = d
    if None in (start, end, t0, t1): return None
    return {"wall": 1000 * (t1 - t0), "start": 1000 * (start - t0), "exit": 1000 * (t1 - end), "script": 1000 * (end - start), "phases": ph}

def read_prof(path):
    sh = OrderedDict(); n = {}
    for l in open(path):
        m = re.match(r"## (.*): ([\d.]+) ms, (\d+) samples", l)
        if m: sh[m.group(1)] = {}; n[m.group(1)] = int(m.group(3)); continue
        if l.startswith("C\t"):
            f = l.rstrip("\n").split("\t")
            sh[f[1]][f[2]] = int(f[3])
    return sh, n

def cell(logdir, c):
    runs = [read_time(p) for p in sorted(glob.glob(f"{logdir}/{c}-time-*.out")) if not p.endswith("-time-0.out")]
    runs = [r for r in runs if r]
    if not runs: return None
    ph = OrderedDict()
    for name in runs[0]["phases"]:
        ph[name] = {k: med([r["phases"][name][k] for r in runs if name in r["phases"]]) for k in runs[0]["phases"][name]}
    out = {"n": len(runs), "wall": med([r["wall"] for r in runs]), "wall_range": (min(r["wall"] for r in runs), max(r["wall"] for r in runs)),
           "start": med([r["start"] for r in runs]), "exit": med([r["exit"] for r in runs]),
           "script": med([r["script"] for r in runs]), "phases": ph}
    out["harness"] = out["script"] - sum(p["ms"] for p in ph.values())
    profs = sorted(glob.glob(f"{logdir}/{c}-prof-*.out"))
    out["classes"] = defaultdict(float); out["byphase"] = OrderedDict(); out["samples"] = 0
    if profs:
        sh, n = read_prof(profs[-1])
        out["samples"] = sum(n.values())
        for name, d in sh.items():
            tot = sum(d.values()) or 1
            t = ph.get(name, {}).get("ms", float("nan"))
            out["byphase"][name] = {k: t * v / tot for k, v in d.items()}
            for k, v in d.items(): out["classes"][k] += t * v / tot
    return out

def main():
    logdir, cells = sys.argv[1], sys.argv[2:]
    data = OrderedDict((c, cell(logdir, c)) for c in cells)
    data = OrderedDict((c, d) for c, d in data.items() if d)
    if not data: print("no runs"); return
    print("| part (ms) | " + " | ".join(data) + " |")
    print("|---|" + "---|" * len(data))
    rows = OrderedDict()
    rows["wall, median (range)"] = [f"**{d['wall']:.0f}** ({d['wall_range'][0]:.0f}-{d['wall_range'][1]:.0f}), n={d['n']}" for d in data.values()]
    rows["Julia's start"] = [f"{d['start']:.0f}" for d in data.values()]
    allcls = defaultdict(float)
    for d in data.values():
        for k, v in d["classes"].items(): allcls[k] += v
    order = sorted(allcls, key=lambda k: -allcls[k])
    for k in order:
        rows[k] = [f"{d['classes'].get(k, 0):.0f}" if d["classes"].get(k, 0) >= 0.5 else "" for d in data.values()]
    rows["the harness (set-up, `_` phases)"] = [f"{d['harness']:.0f}" for d in data.values()]
    rows["exit"] = [f"{d['exit']:.0f}" for d in data.values()]
    rows["profile samples (classed)"] = [str(d["samples"]) for d in data.values()]
    for k, v in rows.items(): print(f"| {k} | " + " | ".join(v) + " |")
    print()
    print("Phases, median of the unprofiled runs: ms (compiling, of it again; the collector) and the classes of 5 % or more:")
    print()
    for c, d in data.items():
        print(f"- **{c}**")
        for name, p in d["phases"].items():
            parts = sorted(d["byphase"].get(name, {}).items(), key=lambda x: -x[1])
            big = "; ".join(f"{k} {v:.0f}" for k, v in parts if p["ms"] and v >= 0.05 * p["ms"])
            print(f"  - {name}: {p['ms']:.1f} ms (compiling {p.get('compile', 0):.1f}, again {p.get('again', 0):.1f}; gc {p.get('gc', 0):.1f}, {p.get('alloc_mb', 0):.0f} MB) | {big}")
    print()

main()
