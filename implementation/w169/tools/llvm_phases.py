#!/usr/bin/env python3
"""W-169 (E-536): Julia's dump of every code generation (`jl_dump_compiles`: ns, then the instance's signature), cut at
the PHASE lines tools/prof.jl writes into it: per phase, the code generations, their time, by class (W-120's), and the
largest. Code generation only (no inference): it covers what --trace-compile does not list, the machine code made for
an instance an image held without it, and code generated inside a hook or a load.

    llvm_phases.py <file.llvm> [N=8]
"""
import sys; sys.dont_write_bytecode = True
import importlib.util, os, re, sys
from collections import OrderedDict, defaultdict
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("ct", os.path.join(here, "..", "..", "w120", "classify_trace.py"))
ct = importlib.util.module_from_spec(spec); spec.loader.exec_module(ct)
spec = importlib.util.spec_from_file_location("top", os.path.join(here, "top.py"))
path = sys.argv[1]; n = int(sys.argv[2]) if len(sys.argv) > 2 else 8
HARNESS = re.compile(r"W169H|census|IdSet\{Core\.CodeInstance\}|show_delim_array|show_at_namedtuple")
ph = OrderedDict(); cur = "(before the first phase)"; ph[cur] = []
for l in open(path, errors="replace"):
    l = l.rstrip("\n")
    if l.startswith("PHASE\t"):
        cur = l.split("\t", 1)[1]; ph.setdefault(cur, []); continue
    m = re.match(r'^(\d+)\t"(.*)"$', l)
    if m:
        ph[cur].append((int(m.group(1)) / 1e6, m.group(2)))
for name, rows in ph.items():
    rows_h = [r for r in rows if HARNESS.search(r[1])]; rows = [r for r in rows if not HARNESS.search(r[1])]
    if not rows: continue
    by = defaultdict(lambda: [0, 0.0])
    for ms, sig in rows:
        c = ct.classify(sig, False); by[c][0] += 1; by[c][1] += ms
    print(f"- **{name}**: {len(rows)} code generations, {sum(r[0] for r in rows):.0f} ms ("
          + ", ".join(f"{c} {v[0]}/{v[1]:.0f} ms" for c, v in sorted(by.items(), key=lambda x: -x[1][1])) + ")"
          + (f"; the harness's {len(rows_h)} left out" if rows_h else ""))
    for ms, sig in sorted(rows, key=lambda r: -r[0])[:n]:
        print(f"  - {ms:.1f} ms `{sig[:150]}`")
