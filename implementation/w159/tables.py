#!/usr/bin/env python3
"""W-159: the round's tables from its logs (medians and ranges over the timed runs; the warm-up `run w` / run 0 left
out). One function per row; prints Markdown.
    python3 tables.py <label> [row ...]      rows: plain loads edit calls sessions nd
"""
import re, sys, statistics as st
from collections import defaultdict

L = sys.argv[1]
LOGS = __file__.rsplit("/", 1)[0] + "/logs"

def cells(path):
    """yield (label, lines) per `== label` cell"""
    cur, buf = None, []
    for line in open(path, errors="replace"):
        if line.startswith("== "):
            if cur: yield cur, buf
            cur, buf = line[3:].split(" | ")[0].strip(), []
        elif cur: buf.append(line.rstrip("\n"))
    if cur: yield cur, buf

def mr(xs, f="{:.2f}"):
    if not xs: return "—"
    m = st.median(xs)
    return (f.format(m) + " (" + f.format(min(xs)) + "–" + f.format(max(xs)) + ", n=" + str(len(xs)) + ")")

def num(pat, lines, conv=float):
    for l in lines:
        m = re.search(pat, l)
        if m: return conv(m.group(1))
    return None

def plain():
    d = defaultdict(lambda: defaultdict(list))
    for lab, ls in cells(f"{LOGS}/g4-plain-{L}.log"):
        if " run w" in lab: continue
        key = lab.rsplit(" run", 1)[0]
        for k, pat in [("load CSV, DataFrames (ms)", r"using CSV, DataFrames ([\d.]+) ms"), ("first work (s)", r"first work ([\d.]+) ms"),
                       ("repeated median (ms)", r"repeated: median ([\d.]+) ms"), ("TraitWorld first (ms)", r"using TraitWorld ([\d.]+) ms"),
                       ("TraitWorld late (ms)", r"using TraitWorld \(late\) ([\d.]+) ms"), ("ended by the late load", r"ended by the library's load: (\d+) of"),
                       ("work after the late load (ms)", r"work after the library's load ([\d.]+) ms")]:
            v = num(pat, ls)
            if v is not None: d[key][k].append(v / 1000 if k == "first work (s)" else v)
    keys = ["load CSV, DataFrames (ms)", "first work (s)", "repeated median (ms)", "TraitWorld first (ms)", "TraitWorld late (ms)", "ended by the late load", "work after the late load (ms)"]
    print("| cell | " + " | ".join(keys) + " |"); print("|---" * (len(keys) + 1) + "|")
    for c in d:
        print(f"| {c} | " + " | ".join(mr(d[c][k], "{:.3f}" if k == "first work (s)" else "{:.0f}" if "ended" in k else "{:.2f}") for k in keys) + " |")

def loads():
    d = defaultdict(lambda: defaultdict(list)); lost = {}
    for lab, ls in cells(f"{LOGS}/g1-loads-{L}.log"):
        if lab.endswith("run w"): continue
        key = lab.rsplit(" run", 1)[0]
        for l in ls:
            m = re.search(r"work: first ([\d.]+) ms.*?after the loads ([\d.]+) ms", l)
            if m: d[key]["first"].append(float(m.group(1)) / 1000); d[key]["after"].append(float(m.group(2)) / 1000)
            m = re.search(r"work: first ([\d.]+) ms", l)
            if m and "after the loads" not in l: d[key]["first"].append(float(m.group(1)) / 1000)
            m = re.search(r"the loads ([\d.]+) ms", l)
            if m: d[key]["loads"].append(float(m.group(1)) / 1000)
            m = re.search(r"^image code \| the eight: (\d+) \(facts (\d+), G2 (\d+)\); lost (\d+) \(facts (\d+)\)\s*(.*)", l)
            if m: lost.setdefault(key, []).append(f"{m.group(4)} of {m.group(1)} (facts {m.group(5)} of {m.group(2)}) {m.group(6)[:90]}")
            m = re.search(r"digest (\w+) \((.*?)\)", l)
            if m: d[key]["digest"] = [m.group(1) + " " + m.group(2)]
    print("| cell | first work (s) | the loads (s) | work after the loads (s) | own image instances lost (the eight packages) | digest |")
    print("|---|---|---|---|---|---|")
    for c in d:
        lv = sorted(set(lost.get(c, [])))
        print(f"| {c} | {mr(d[c]['first'])} | {mr(d[c]['loads'])} | {mr(d[c]['after'])} | {'; '.join(lv)} | {(d[c]['digest'] or ['—'])[0]} |")

def edit():
    d = defaultdict(lambda: defaultdict(list))
    for lab, ls in cells(f"{LOGS}/g1-edit-{L}.log"):
        if lab.endswith("run w"): continue
        key = lab.rsplit(" run", 1)[0]
        for l in ls:
            m = re.match(r"^(\S.{0,27}?)\s+first ([\d.]+) ms \(compile ([\d.]+) ms.*?again ([\d.]+) ms \| defining ([\d.]+) ms \| ended (\d+) by the definition, (\d+) at the end.*?compiled own (\d+)", l)
            if m:
                st_ = m.group(1).strip()
                d[key][st_ + " | first (ms)"].append(float(m.group(2)))
                d[key][st_ + " | defining (ms)"].append(float(m.group(5)))
                d[key][st_ + " | ended"].append(int(m.group(6)) + int(m.group(7)))
                d[key][st_ + " | compiled own"].append(int(m.group(8)))
            m = re.search(r"^digest (\w+) \((.*)\)|^digest (\w+) DIFFERS", l)
            if m: d[key]["digest"].append(l[7:60])
    for c in d:
        print(f"\n**{c}**\n\n| step | first (ms) | defining (ms) | ended | compiled own |\n|---|---|---|---|---|")
        steps = []
        for k in d[c]:
            s = k.split(" | ")[0]
            if s not in steps and k != "digest": steps.append(s)
        for s in steps:
            print(f"| {s} | {mr(d[c][s + ' | first (ms)'], '{:.1f}')} | {mr(d[c][s + ' | defining (ms)'], '{:.1f}')} | {mr(d[c][s + ' | ended'], '{:.0f}')} | {mr(d[c][s + ' | compiled own'], '{:.0f}')} |")
        if d[c]["digest"]: print(f"\ndigests: {sorted(set(d[c]['digest']))}")

def calls():
    d = defaultdict(list); order = []
    for lab, ls in cells(f"{LOGS}/g2-calls-{L}.log"):
        s = lab.split()[0]
        for l in ls:
            m = re.match(r"^\| (\d+ [^|]+?) \| ([^|]+?) \| ([\d.]+) \|", l)
            if m:
                k = (m.group(1), m.group(2), s)
                if (m.group(1), m.group(2)) not in order: order.append((m.group(1), m.group(2)))
                d[k].append(float(m.group(3)))
    print("| row | form | head (ns) | tag (ns) |\n|---|---|---|---|")
    for r, f in order:
        print(f"| {r} | {f} | {mr(d[(r, f, 'H')])} | {mr(d[(r, f, 'B')])} |")

def sessions():
    d = defaultdict(lambda: defaultdict(list))
    for line in open(f"{LOGS}/g6-sessions-{L}.log", errors="replace"):
        m = re.match(r"^(\w) (\S+) run \d+: wall ([\d.]+) s \| load ([\d.]+).*?\| (.*)", line)
        if m:
            k = (m.group(2), m.group(1)); d[k]["wall"].append(float(m.group(3)))
            for name, pat in [("load", r"load ([\d.]+) ms"), ("first run", r"first run ([\d.]+) ms")]:
                mm = re.search(pat, m.group(5))
                if mm: d[k][name].append(float(mm.group(1)))
            d[k]["mark"] = [m.group(5)[:200]]
    print("| session | setting | wall (s) | marks (the last run) |\n|---|---|---|---|")
    for k in d: print(f"| {k[0]} | {k[1]} | {mr(d[k]['wall'])} | {d[k]['mark'][0]} |")

def nd():
    d = defaultdict(lambda: defaultdict(list))
    for line in open(f"{LOGS}/g2-nd-{L}.log", errors="replace"):
        m = re.match(r"^== (\w) run (\d+).*?session ([\d.]+) s.*?\| (W total.*?)? \| T again: ([\d.]+) ms", line)
        if m and m.group(2) != "0":
            d[m.group(1)]["session"].append(float(m.group(3))); d[m.group(1)]["again"].append(float(m.group(5)))
    print("| setting | session (s) | T again (ms, summed) |\n|---|---|---|")
    for s in d: print(f"| {s} | {mr(d[s]['session'])} | {mr(d[s]['again'], '{:.1f}')} |")

for r in (sys.argv[2:] or ["plain"]):
    print(f"\n### {r}\n"); globals()[r]()
