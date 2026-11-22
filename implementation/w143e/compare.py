#!/usr/bin/env python3
# W-143e (E-541; W-143d's compare.py): the census of two labels side by side, per session: the share, and per group the culprits and
# the own facts instances that need the group.      python3 compare.py <before> <after> [forks facts ode]
import re, sys, os
H = os.path.dirname(os.path.abspath(__file__))
def read(label, s):
    t = open(f"{H}/logs/{label}-{s}.log").read()
    m = re.search(r"own facts instances (\d+) \(([\d.]+) %\) of (\d+)", t)
    share = f"{m.group(1)} of {m.group(3)} ({m.group(2)} %)"
    cul = dict(re.findall(r"^(.*?)\s+culprits\s+(\d+) \|", t, re.M))
    need = dict(re.findall(r"^(.*?)\s+without it .*\| needs it (\d+)", t, re.M))
    tot = re.search(r"culprits \(a fault of their own\) (\d+)", t).group(1)
    return share, cul, need, tot
a, b = sys.argv[1], sys.argv[2]
for s in (sys.argv[3:] or ["forks", "facts", "ode"]):
    try:
        A, B = read(a, s), read(b, s)
    except FileNotFoundError as e:
        print("missing", e); continue
    print(f"\n### {s}: own facts instances in the class {A[0]} -> {B[0]}; culprits {A[3]} -> {B[3]}\n")
    print(f"| group | culprits {a} | {b} | needed by {a} | {b} |\n|---|---|---|---|---|")
    for g in A[1]:
        print(f"| {g.strip()} | {A[1][g]} | {B[1].get(g,'?')} | {A[2].get(g,'?')} | {B[2].get(g,'?')} |")
