#!/usr/bin/env python3
"""W-120, phase 3's first step: what a session still compiles that no image holds.
Reads a `--trace-compile --trace-compile-timing` file and puts each compiled signature in one class:

  session      it names a type or function of Main: the session's own code, or library code compiled
               for the session's types and functions. No image can hold it before the session exists.
  recompile    Julia marks it as compiled again: code an image held, invalidated in this session.
  own image    every type it names is the function's package's or Julia's: the package's own image could
               hold it (a workload line).
  composition  it names types of two or more packages besides Julia's: no single package's image holds
               it today; a dependent's image, an extension's, or a cache across sessions could.
  julia        function and types are all Julia's (Core, Base, the standard libraries): the system
               image or a standard library's image could hold it.

Usage: classify_trace.py <trace> [<trace> ...]      prints a table per file, and each line with -v
"""
import re, sys
JULIA = {"Core", "Base", "Main"} | set("""Dates LinearAlgebra Random Printf Test Logging Markdown Unicode
Serialization Sockets Statistics SparseArrays Distributed InteractiveUtils REPL Pkg TOML UUIDs SHA Mmap
Libdl Artifacts Preferences Compiler""".split())
BUILTIN_TYPES = set("""Tuple Array Vector Matrix Int64 Int32 Int8 UInt8 UInt16 UInt32 UInt64 Float64 Float32 Bool
String Symbol Nothing Any Type Union Memory GenericMemory MemoryRef NamedTuple Pair Dict Set IdDict Char
Function TypeVar Val Ref Ptr DataType UnionAll Module Missing Expr Method NTuple Vararg Integer Real Number
AbstractArray AbstractVector AbstractString IO IOBuffer IOContext SubString StepRange UnitRange Colon typeof
Float16 Int16 Int128 UInt128 BitArray BitVector Complex Rational Some Task Dynamic Callable All Kept""".split())
line_re = re.compile(r"^#=\s*([0-9.]+) ms =# precompile\((.*)\)(\s*#\s*recompile)?\s*$")
name_re = re.compile(r"(?:(?<=[^A-Za-z0-9_.!\"#])|^)((?:[A-Z][A-Za-z0-9_]*\.)+)(?:[A-Za-z_!#\"@]|var\")")

def modules(sig):
    """root modules named in a signature, by its qualified names"""
    return {m.group(1).split(".")[0] for m in name_re.finditer(sig)}

def fmod(sig):
    m = re.match(r"Tuple\{(?:typeof\(|Type\{)?([A-Za-z0-9_.]+)", sig)
    if not m: return None
    parts = m.group(1).split(".")
    return parts[0] if len(parts) > 1 else "Base"

def classify(sig, recompile):
    mods = modules(sig)
    if recompile: return "recompile"
    if "Main" in mods: return "session"
    pk = mods - JULIA
    if not pk: return "julia"
    return "own image" if len(pk) == 1 else "composition"

def main():
    verbose = "-v" in sys.argv
    for path in [a for a in sys.argv[1:] if a != "-v"]:
        rows = []
        for l in open(path):
            m = line_re.match(l.strip())
            if not m: continue
            ms, sig, rec = float(m.group(1)), m.group(2), bool(m.group(3))
            rows.append((classify(sig, rec), ms, sig))
        tot = sum(r[1] for r in rows)
        print(f"{path}: {len(rows)} compiles, {tot:.0f} ms")
        for c in ("session", "recompile", "own image", "composition", "julia"):
            sel = [r for r in rows if r[0] == c]
            t = sum(r[1] for r in sel)
            print(f"  {c:12s} {len(sel):4d} compiles {t:8.1f} ms {100*t/tot if tot else 0:5.1f} %")
            if verbose:
                for _, ms, sig in sorted(sel, key=lambda r: -r[1])[:12]:
                    print(f"      {ms:7.1f} ms  {sig[:200]}")
if __name__ == "__main__":
    main()
