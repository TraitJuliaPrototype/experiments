#!/usr/bin/env python3
"""E-264, part 2: structs with a type parameter bounded by a trait, from the ports' sources.

TraitWorld erases a trait bound on a struct parameter to `Any` (it checks at construction), so the runtime
cannot list them. Under the draft each such struct's default constructor sets the parameter from the
argument's type: an open method (traits §8.2). The trait names are every `@trait Name` in the sources
scanned, with BaseTraits' and `Callable`. Public: the struct's name in an `export` or `public` list of
its file. Usage: structs.py <repo root>  (prints a table and the counts per port)."""
import os, re, sys

R = sys.argv[1]
PORTS = {
    "BaseTraits": ["TraitWorld/src/BaseTraits.jl"],
    "Tables": ["forks/Tables/src"], "DataFrames": ["forks/DataFrames/src"], "CSV": ["forks/CSV/src"],
    "TraitMakie": ["TraitMakie/src"], "MakieCompat": ["TraitMakie/compat/MakieCompat/src"],
    "Graphs": ["ndport/pkgs/Graphs-p4/src"], "GraphMakie": ["ndport/pkgs/GraphMakie-ports/src"],
    "NetworkDynamics": ["ndport/pkgs/NetworkDynamics-ports/src"],
    "TraitDifferentialEquations": ["TraitDifferentialEquations/src"],
    "ODECore": ["TraitDifferentialEquations/lib/ODECore/src"],
    "TraitArrayTools": ["TraitDifferentialEquations/lib/TraitArrayTools/src"],
    "TraitIndexing": ["TraitDifferentialEquations/lib/TraitIndexing/src"],
    "TraitNonlinearSolve": ["TraitDifferentialEquations/lib/TraitNonlinearSolve/src"],
    "TraitRodas": ["TraitDifferentialEquations/lib/TraitRodas/src"],
    "TraitTables": ["TraitTables/src"], "TraitCSV": ["TraitCSV/src"], "TraitReport": ["TraitReport/src"],
}

def files(paths):
    for p in paths:
        full = os.path.join(R, p)
        if os.path.isfile(full):
            yield full
        else:
            for d, _, fs in os.walk(full):
                for f in fs:
                    if f.endswith(".jl"):
                        yield os.path.join(d, f)

texts = {port: {f: open(f, encoding="utf-8", errors="replace").read() for f in files(ps)} for port, ps in PORTS.items()}
traits = {"Callable"}
for port in texts:
    for t in texts[port].values():
        traits |= set(re.findall(r"@trait\s+([A-Z]\w*)", t))

struct_re = re.compile(r"^\s*(?:mutable\s+)?struct\s+(\w+)\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}", re.M)
rows = []
for port, fs in texts.items():
    for f, t in fs.items():
        exported = set()
        for m in re.finditer(r"^\s*(?:export|public)\s+([^\n#]+)", t, re.M):
            exported |= {x.strip() for x in m.group(1).split(",")}
        for m in struct_re.finditer(t):
            name, params = m.group(1), m.group(2)
            bounded = [b for b in re.findall(r"(\w+)\s*<:\s*([A-Za-z_][\w.]*)", params) if b[1].split(".")[-1] in traits]
            if bounded:
                line = t[:m.start()].count("\n") + 1
                rows.append((port, name, os.path.relpath(f, R) + ":" + str(line),
                             "public" if name in exported else "internal",
                             ", ".join(f"{a} <: {b}" for a, b in bounded)))
rows.sort()
print("port\tstruct\tlocation\tvisibility\tparameters bounded by a trait")
for r in rows:
    print("\t".join(r))
print()
for port in PORTS:
    rs = [r for r in rows if r[0] == port]
    if rs:
        print(f"# {port}: {len(rs)} (public {sum(r[3] == 'public' for r in rs)}): " + ", ".join(r[1] for r in rs))
print(f"# total: {len(rows)} (public {sum(r[3] == 'public' for r in rows)}); trait names scanned: {len(traits)}")
