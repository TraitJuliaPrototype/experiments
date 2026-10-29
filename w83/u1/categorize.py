# Categorize what open samples reach (logs/results-<v>.tsv), for the README. Usage: python3 categorize.py B
import csv, sys, collections
v = sys.argv[1] if len(sys.argv) > 1 else "B"
CAT = {
  "generic callee": {"copyto!", "cmp", "map!", "copymutable", "checked_length", "count", "findfirst", "reverse!",
      "deleteat!", "nextind", "groupreduce", "groupreduce!_helper", "copyto_widen!", "connected_components!",
      "outdegree", "indegree", "neighbors", "all_neighbors", "float_type", "checkbounds", "axes1", "LinearIndices",
      "unalias", "copyto_unaliased!", "collect_similar", "isassigned", "first", "isempty", "nrow", "index", "size",
      "getindex", "kwcall", "firstindex", "lastindex", "eachindex", "similar", "axes", "IndexStyle", "length",
      "iterate", "setindex!", "vertices", "edges", "outneighbors"},
  "adaptor keeps the value": {"zip", "enumerate", "Base.Generator", "view", "dotview", "broadcasted", "materialize!",
      "Base.IteratorSize", "_array_for", "Vector{Float64}", "copy", "vcat", "constructs IMStub{typeof(t)}(t, …)"},
  "eltype": {"eltype"},
  "returns the argument": {"returned (escapes)"},
  "identity or type test": {"builtin ===", "builtin isa", "typeof"},
  "passed to a function argument": {"unknown function"},
  "shown in an error": {"BoundsError"},
}
def cat(op):
    if "undeclared arity" in op: return "contract op at another arity"
    for c, s in CAT.items():
        if op in s: return c
    return "other: " + op
rows = list(csv.DictReader(open(f"logs/results-{v}.tsv"), delimiter="\t"))
by = collections.Counter(); only = collections.Counter(); n = len(rows)
for r in rows:
    if r["status"] != "open": continue
    cs = sorted({cat(o) for o in r["reached"].split("; ") if o})
    for c in cs: by[c] += 1
    only[" + ".join(cs)] += 1
print(f"variant {v}: {n} samples, {sum(r['status']=='bounded' for r in rows)} fully bounded")
print("open functions reaching each category:")
for c, k in by.most_common(): print(f"  {k:3d}  {c}")
print("open functions by their set of categories:")
for c, k in only.most_common(): print(f"  {k:3d}  {c}")
