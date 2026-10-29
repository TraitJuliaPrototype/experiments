"""E-253 (U5): per code base, from the census TSVs: sets by mode, bounded methods, hits. Run: python3 summary.py"""
import csv, collections, os
D = os.path.dirname(os.path.abspath(__file__))
SESS = ["tw", "tables", "tde", "makie", "forks", "ndport"]
def base_of(mod):
    if mod.startswith("TraitWorld.BaseTraits"): return "BaseTraits"
    if mod.startswith("TraitWorld._P"): return "TraitWorld (internal workload)"
    r = mod.split(".")[0]
    return {"TraitWorld": "TraitWorld", "TraitTables": "TraitTables", "TraitCSV": "TraitCSV",
            "TraitCSVInlineStringsExt": "TraitCSV",
            "ODECore": "TDE", "TraitArrayTools": "TDE", "TraitIndexing": "TDE", "TraitNonlinearSolve": "TDE",
            "TraitRodas": "TDE", "TraitImplicit": "TDE", "TraitLinSolvers": "TDE", "TraitNLSolvers": "TDE",
            "TraitDifferentialEquations": "TDE", "TraitMakie": "TraitMakie", "MakieCompat": "MakieCompat",
            "CSV": "forks", "Tables": "forks", "DataFrames": "forks", "NetworkDynamics": "ndport", "Graphs": "ndport",
            "GraphMakie": "ndport"}.get(r, r)
def rows(f):
    with open(os.path.join(D, f)) as fh: return list(csv.DictReader(fh, delimiter="\t"))
sets = {}
for s in SESS:
    for r in rows(f"{s}-sets.tsv"):
        k = (r["module"], r["set"])
        if k not in sets or int(r["members"]) > int(sets[k]["members"]): sets[k] = r
bounded = {}
for s in SESS:
    for r in rows(f"{s}-bounded.tsv"):
        bounded[(r["method"])] = r
hits = []
for s in SESS: hits += rows(f"{s}-hits.tsv")
mode_of = {r["set"]: (r["mode"], r["mode_refined"]) for r in sets.values()}
order = ["TraitWorld", "BaseTraits", "TraitTables", "TraitCSV", "TDE", "TraitMakie", "MakieCompat", "forks", "ndport", "TraitWorld (internal workload)"]
agg = collections.OrderedDict((b, collections.Counter()) for b in order)
for r in sets.values():
    b = base_of(r["module"]); c = agg.setdefault(b, collections.Counter())
    c["sets"] += 1; c["set:" + r["mode"]] += 1; c["setref:" + r["mode_refined"]] += 1
for r in bounded.values():
    b = base_of(r["defining_module"]); c = agg.setdefault(b, collections.Counter())
    c["bounded"] += 1
    if r["foreign_fn"] == "true" or r["in_extension"] == "true": c["foreign_or_ext"] += 1
    sets_named = [x.split(":", 1)[1] for x in r["bounds"].split(" ")]
    names = [n for x in sets_named for n in x.split("+")]
    if any(n != "Callable" and mode_of.get(n, ("?",))[0] == "open" for n in names): c["by_open_set"] += 1
for r in hits:
    c = agg[base_of(r["package"])]; c["hits"] += 1
    if r["unshielded"] not in ("-", ""): c["unshielded"] += 1
print("code base | sets | members by owner (strict / refined) | open (strict / refined) | no members | bounded methods | of them bounded by an open set (own functions) | on a foreign function or in an extension | hits | unshielded")
for b, c in agg.items():
    if not c: continue
    print(f"{b} | {c['sets']} | {c['set:members_by_owner']} / {c['setref:members_by_owner']} | {c['set:open']} / {c['setref:open']} | {c['set:no_members']} | {c['bounded']} | {c['by_open_set']} | {c['foreign_or_ext']} | {c['hits']} | {c['unshielded']}")
