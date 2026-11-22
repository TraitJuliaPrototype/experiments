#!/usr/bin/env python3
"""W-169 (E-536): what a session compiles, classed (W-120's classes, ../../w120/classify_trace.py): session (names
Main: the session's own), recompile (compiled again: code an image or the session held, ended), own image (one
package's types and Julia's: its image could hold it), composition (two packages' types), julia (Julia's own: the
system image or a standard library's could hold it).

    top.py <logdir>/<cell>-trace-<run> [N=20]     reads <..>.trace, <..>.census, <..>.llvm

- the trace (--trace-compile-timing): each compile dispatched at run time, with inference and code generation of
  everything below it; the N largest, classed;
- the census (tools/census.jl): every code instance the process inferred (made outside every image) or generated
  machine code for, by class, with its own inference and code generation; "image, no machine code": an image held
  the inferred code, the session made the machine code (PE-32's pattern);
- the harness's own instances (its driver, the census, the lines it prints) are left out where they can be told
  (HARNESS below), and counted apart.
"""
import sys; sys.dont_write_bytecode = True
import importlib.util, os, re, sys
from collections import defaultdict
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("ct", os.path.join(here, "..", "..", "w120", "classify_trace.py"))
ct = importlib.util.module_from_spec(spec); spec.loader.exec_module(ct)
# the harness's own instances, and what --trace-compile itself compiles to print a signature (show of a tuple of
# symbols, a NamedTuple's names, a type through sprint)
HARNESS = re.compile(r"show\), Base\.IOContext\{Base\.GenericIOBuffer\{Memory\{UInt8\}\}\}, (NTuple|Tuple\{Symbol)|show_delim_array\), (Base\.)?IOContext\{(Base\.)?IOBuffer\}|show_at_namedtuple|##sprint#\d+\", Pair\{Symbol, Module\}|W169H|census|IdSet\{Core\.CodeInstance\}|Dict\{String, (Base\.)?Vector\{Float64\}\}|Pair\{String, (Base\.)?Vector\{Float64\}\}|print_to_string\), String, String, String, Float64")

def trace_rows(path):
    out = []
    if not os.path.exists(path): return out
    for l in open(path):
        m = ct.line_re.match(l.strip())
        if m:
            out.append((ct.classify(m.group(2), bool(m.group(3))), float(m.group(1)), m.group(2)))
    return out

def census_rows(path):
    out = []
    if not os.path.exists(path): return out
    for l in open(path):
        f = l.rstrip("\n").split("\t")
        if len(f) < 8 or f[0] != "CI": continue
        inf, gen, where, again, valid, facts, sig = float(f[1]), float(f[2]), f[3], f[4] == "again", f[5], f[6], f[7]
        c = ct.classify(sig, again)
        out.append((c, inf, gen, where, valid, facts, sig))
    return out

def main():
    base = sys.argv[1]; n = int(sys.argv[2]) if len(sys.argv) > 2 else 20
    tr = trace_rows(base + ".trace")
    h = [x for x in tr if HARNESS.search(x[2])]; tr = [x for x in tr if not HARNESS.search(x[2])]
    print(f"`{os.path.basename(base)}.trace`: {len(tr)} compiles dispatched, {sum(x[1] for x in tr):.0f} ms (the harness's {len(h)}, {sum(x[1] for x in h):.0f} ms, left out)")
    print()
    print("| class | compiles | ms |\n|---|---|---|")
    for c in ("session", "recompile", "own image", "composition", "julia"):
        sel = [x for x in tr if x[0] == c]
        print(f"| {c} | {len(sel)} | {sum(x[1] for x in sel):.0f} |")
    print()
    print(f"The {n} largest:\n")
    print("| ms | class | signature |\n|---|---|---|")
    for c, ms, sig in sorted(tr, key=lambda x: -x[1])[:n]:
        print(f"| {ms:.1f} | {c} | `{sig[:170]}` |")
    print()
    ce = census_rows(base + ".census")
    if ce:
        hc = [x for x in ce if HARNESS.search(x[6])]; ce = [x for x in ce if not HARNESS.search(x[6])]
        print(f"`{os.path.basename(base)}.census`: {len(ce)} instances inferred or given machine code in the process (the harness's {len(hc)} left out)")
        print()
        print("| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |\n|---|---|---|---|---|")
        agg = defaultdict(lambda: [0, 0.0, 0.0])
        for c, inf, gen, where, valid, facts, sig in ce:
            k = ("inferred in the session" if where == "session" else "image, no machine code", c)
            a = agg[k]; a[0] += 1; a[1] += inf; a[2] += gen
        for k, a in sorted(agg.items(), key=lambda x: -(x[1][1] + x[1][2])):
            print(f"| {k[0]} | {k[1]} | {a[0]} | {a[1]:.0f} | {a[2]:.0f} |")
        tot = [sum(x[1] for x in ce), sum(x[2] for x in ce)]
        print(f"| all | | {len(ce)} | {tot[0]:.0f} | {tot[1]:.0f} |")
        print()
        print("The census's 12 largest (inference + code generation of the instance alone):\n")
        print("| ms (inf + gen) | where | class | signature |\n|---|---|---|---|")
        for c, inf, gen, where, valid, facts, sig in sorted(ce, key=lambda x: -(x[1] + x[2]))[:12]:
            print(f"| {inf:.1f} + {gen:.1f} | {where} | {c} | `{sig[:150]}` |")
        print()

main()
