# E-195 (3): fingerprints at scale. A workload session; every CodeInstance of owner :facts it made that names no type of
# the session is an entry; its fingerprint (Fingerprints.jl) and its code witness are recorded, or checked against a
# recording: equal fingerprints, candidate-index hits, and the witness.
#     X_MODE=record|check X_FILE=... julia --project=<env> fp_scale.jl <workload script> <outdir>
const NEW = Any[]
ccall(:jl_set_newly_inferred, Cvoid, (Any,), NEW)
const SYSIMG = Set(string(id.name) for id in keys(Base.loaded_modules))
const _SCRIPT, _OUT = ARGS[1], ARGS[2]
empty!(ARGS); push!(ARGS, _OUT)
include(joinpath(dirname(@__DIR__), "ttfx", _SCRIPT))
ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
include(joinpath(@__DIR__, "Fingerprints.jl"))
using .Fingerprints: entry_fp, entry_key, code_witness, pkgof, mi_of, stakeholders
using Serialization
const FAIL = Ref(0)
# the candidates an entry saw at record: methods from outside each fact's stakeholders and the system image that
# intersect the fact, by fingerprint, with their names (for diagnosis)
function outsiders(sigs)
    out = Tuple{UInt,String}[]
    for sig in sigs
        sig isa DataType && sig <: Tuple && length(sig.parameters) >= 1 || continue
        ft = sig.parameters[1]; ft isa DataType && isdefined(ft, :instance) || continue
        sh = stakeholders(sig)
        for meth in methods(ft.instance)
            q = pkgof(meth.module); (q in sh || q in SYSIMG) && continue
            typeintersect(meth.sig, sig) === Union{} || push!(out, (Fingerprints.method_fp(meth), string(q, ": ", meth.sig)))
        end
    end
    return sort!(unique!(out))
end
let
    loaded = Set(string(id.name) for id in keys(Base.loaded_modules) if id.name != "Main")
    session(@nospecialize(x)) = x isa Union ? (session(x.a) || session(x.b)) : x isa UnionAll ? session(x.body) :
        x isa DataType ? ((p = pkgof(x.name.module); p !== nothing && !(p in loaded)) || any(session, x.parameters)) : false
    entries = Dict{String,Any}()
    for ci in NEW
        ci isa Core.CodeInstance && ci.owner === :facts || continue
        mi = mi_of(ci); m = mi.def; m isa Method || continue
        p = pkgof(m.module); (p !== nothing && !(p in loaded)) && continue
        session(mi.specTypes) && continue
        sigs = isdefined(ci, :edges) ? Any[e isa Core.CodeInstance ? mi_of(e).specTypes : e isa Core.MethodInstance ? e.specTypes : e
                                          for e in ci.edges if e isa Union{Core.CodeInstance,Core.MethodInstance,Type}] : Any[]
        fp = try entry_fp(ci)[1] catch err
            FAIL[] += 1
            FAIL[] <= 5 && println("F ", entry_key(ci)[1:min(end, 120)], " => ", first(sprint(showerror, err), 300))
            nothing
        end
        fp === nothing && continue
        entries[entry_key(ci)] = (fp = fp, w = code_witness(ci), sigs = sigs, out = outsiders(sigs))
    end
    file = get(ENV, "X_FILE", "logs/fp-scale.jls")
    if get(ENV, "X_MODE", "record") == "record"
        serialize(file, entries); println("S recorded ", length(entries), " entries; fingerprint failures ", FAIL[])
    else
        rec = deserialize(file)
        both = intersect(keys(rec), keys(entries))
        anyhit = 0; seen = Dict{String,Int}()
        eq = 0; hit = 0; kept = 0; unsound = 0; imprecise = 0; differs = 0
        for k in both
            r = rec[k]; e = entries[k]
            # any candidate (the index of revision 2), and a candidate the entry did not see at record (the refinement)
            cur = outsiders(r.sigs)
            any_hit = !isempty(cur); any_hit && (anyhit += 1)
            h = cur != r.out
            foreach(o -> (seen[o[2]] = get(seen, o[2], 0) + 1), cur)
            same = e.fp == r.fp; same && (eq += 1); h && (hit += 1)
            caught = !same || h; caught || (kept += 1)
            d = e.w != r.w; d && (differs += 1)
            d && !caught && (unsound += 1)
            !d && caught && (imprecise += 1)
        end
        println("S entries recorded ", length(rec), ", in this session ", length(entries), ", in both ", length(both))
        println("S fingerprints equal ", eq, "; index hits ", hit, "; kept (equal, no hit) ", kept, " = ", round(100kept / max(length(both), 1); digits = 1), "%")
        println("S entries with any candidate (revision 2's index) ", anyhit, "; with a candidate not seen at record ", hit)
        for (k, n) in sort!(collect(seen); by = last, rev = true)[1:min(end, 12)]
            println("S   candidate ", first(k, 140), " in ", n, " entries")
        end
        println("S code differs ", differs, "; unsound (code differs, kept) ", unsound, "; imprecise (code same, not kept) ", imprecise)
    end
end
