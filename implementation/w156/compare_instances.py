#!/usr/bin/env python3
"""W-156, second part: the forks' audit. Compares two lists of compiled instances (forks_session.jl's INSTANCES files,
`module<TAB>method<TAB>file:line<TAB>specTypes`) by method: the count before and after, largest growth first, and
for each method that grew, the instances it gained (with -v, all of them; else the first few).

    compare_instances.py <before.tsv> <after.tsv> [-v] [-n N] [--trace after.trace]      N methods listed (default 40)

With --trace (a `--trace-compile` file of a session after the change): the session's compiles of a function that
before had an instance at a trait's own type (compiled once there: the sign of the module option `first_seen`),
grouped by function. These are the sites that compile per type in the session where they compiled once before.
"""
import re
import sys
from collections import defaultdict


def read(path):
    by = defaultdict(set)
    for line in open(path):
        parts = line.rstrip("\n").split("\t")
        if len(parts) != 4:
            continue
        mod, name, loc, spec = parts
        by[(mod, name, loc)].add(spec)
    return by


def main(argv):
    verbose = "-v" in argv
    n = 40
    if "-n" in argv:
        n = int(argv[argv.index("-n") + 1])
    trace = argv[argv.index("--trace") + 1] if "--trace" in argv else None
    files = [a for i, a in enumerate(argv) if not a.startswith("-") and not (i > 0 and argv[i - 1] in ("-n", "--trace"))]
    a, b = read(files[0]), read(files[1])
    keys = set(a) | set(b)
    ta, tb = sum(len(v) for v in a.values()), sum(len(v) for v in b.values())
    print(f"instances with code: {ta} before, {tb} after ({tb - ta:+d}); methods with code: {len(a)} before, {len(b)} after")
    by_mod = defaultdict(lambda: [0, 0])
    for k in keys:
        by_mod[k[0]][0] += len(a.get(k, ()))
        by_mod[k[0]][1] += len(b.get(k, ()))
    for m, (x, y) in sorted(by_mod.items()):
        print(f"  {m}: {x} -> {y} ({y - x:+d})")
    rows = sorted(keys, key=lambda k: (-(len(b.get(k, ())) - len(a.get(k, ()))), k))
    grew = [k for k in rows if len(b.get(k, ())) > len(a.get(k, ()))]
    shrank = [k for k in rows if len(b.get(k, ())) < len(a.get(k, ()))]
    print(f"methods that grew: {len(grew)} (+{sum(len(b.get(k, ())) - len(a.get(k, ())) for k in grew)}), "
          f"shrank: {len(shrank)} ({sum(len(b.get(k, ())) - len(a.get(k, ())) for k in shrank)})")
    print("\ngrowth  before  after  method")
    for k in grew[:n]:
        x, y = len(a.get(k, ())), len(b.get(k, ()))
        print(f"{y - x:+6d}  {x:6d}  {y:5d}  {k[0]}.{k[1]}  {k[2]}")
        new = sorted(b.get(k, set()) - a.get(k, set()))
        gone = sorted(a.get(k, set()) - b.get(k, set()))
        for s in (new if verbose else new[:3]):
            print(f"            + {s[:240]}")
        if not verbose and len(new) > 3:
            print(f"            … {len(new) - 3} more")
        for s in (gone if verbose else gone[:2]):
            print(f"            - {s[:240]}")
    if shrank:
        print("\nshrank  before  after  method")
        for k in shrank[:n]:
            x, y = len(a.get(k, ())), len(b.get(k, ()))
            print(f"{y - x:+6d}  {x:6d}  {y:5d}  {k[0]}.{k[1]}  {k[2]}")
            for s in sorted(a.get(k, set()) - b.get(k, set()))[: (1000 if verbose else 2)]:
                print(f"            - {s[:240]}")
    if trace:
        trace_sites(a, trace)


TRAIT = re.compile(r"(Tables\.ColumnCore\.(Column|PooledColumn|TableSource)|"
                   r"CSV\.ColumnParsers\.(CSVSource|CSVColumn|TextColumn))(\{[^{}]*\})?( where .*)?")
FNAME = re.compile(r"Tuple\{typeof\(([^)]*)\)")


def top_args(spec):
    """the top-level arguments of `Tuple{…}`, the function's type first"""
    inner = spec[spec.index("{") + 1:spec.rindex("}")] if "{" in spec else ""
    out, depth, cur = [], 0, ""
    for ch in inner:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur.strip()); cur = ""
        else:
            cur += ch
    out.append(cur.strip())
    return out


def at_trait(spec):
    """an argument (not the function) whose type is a trait's own, not a container of it, a box or a wrapper"""
    return any(TRAIT.fullmatch(a + ",") is not None or TRAIT.fullmatch(a) is not None for a in top_args(spec)[1:])


def trace_sites(before, trace):
    once = defaultdict(list)          # function name -> its instances at a trait's own type, before
    for (mod, name, loc), specs in before.items():
        for sp in specs:
            m = FNAME.match(sp)
            if m and at_trait(sp):
                once[m.group(1)].append(sp)
    hits = defaultdict(list)
    n = 0
    for line in open(trace):
        if not line.startswith("precompile("):
            continue
        n += 1
        m = FNAME.search(line)
        if m and m.group(1) in once:
            hits[m.group(1)].append(line.strip()[len("precompile("):-1])
    print(f"\nthe session's compiles ({n} in the trace) of a function that before had an instance at a trait's own type: "
          f"{sum(len(v) for v in hits.values())}, of {len(hits)} functions")
    for f, sigs in sorted(hits.items(), key=lambda kv: -len(kv[1])):
        print(f"{len(sigs):4d}  {f}    (before, at the trait: {once[f][0][:160]})")
        for sg in sigs[:4]:
            print(f"        {sg[:220]}")


if __name__ == "__main__":
    main(sys.argv[1:])
