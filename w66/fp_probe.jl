# E-195: each case's entry (P<i>.Impl.go's facts CodeInstance) identified by fingerprints (Fingerprints.jl), recorded in
# one session and checked in another: fingerprints equal or not, the candidate index, against the compiled code.
#     X_MODE=record|check X_PRELOAD=... julia --project=env_<v> fp_probe.jl
using Serialization
include("Fingerprints.jl"); using .Fingerprints: entry_fp, code_witness, pkgof
const SYSIMG = Set(string(id.name) for id in keys(Base.loaded_modules))
pre = get(ENV, "X_PRELOAD", "")
isempty(pre) || Base.require(Main, Symbol(pre))
mods = Dict(i => Base.require(Main, Symbol("P$i")) for i in 1:6)
for i in 1:6; Base.invokelatest(getglobal(mods[i], :go)); end
function facts_ci(m::Module)
    meth = only(methods(getglobal(getglobal(m, :Impl), :go)))
    for mi in Base.specializations(meth)
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci isa Core.CodeInstance
            ci.owner === :facts && return ci
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
end
sigs_of(ci) = isdefined(ci, :edges) ? Any[e isa Core.CodeInstance ? Fingerprints.mi_of(e).specTypes : e isa Core.MethodInstance ? e.specTypes : e
                                          for e in ci.edges if e isa Union{Core.CodeInstance,Core.MethodInstance,Type}] : Any[]
"The candidate index: methods of the facts' functions from outside the facts' stakeholders and the system image."
function index_hits(sigs)
    hits = String[]
    for sig in sigs
        sig isa DataType && sig <: Tuple && length(sig.parameters) >= 1 || continue
        ft = sig.parameters[1]; ft isa DataType && isdefined(ft, :instance) || continue
        sh = Fingerprints.stakeholders(sig)
        for meth in methods(ft.instance)
            p = pkgof(meth.module)
            (p in sh || p in SYSIMG) && continue
            typeintersect(meth.sig, sig) === Union{} || push!(hits, "$(p)")
        end
    end
    unique(hits)
end
const MODE = get(ENV, "X_MODE", "record"); const FILE = get(ENV, "X_FILE", "logs/fp-recorded.jls")
rec = MODE == "check" ? deserialize(FILE) : Dict{Int,Any}()
for i in 1:6
    ci = facts_ci(mods[i])
    fp, parts = entry_fp(ci); w = code_witness(ci); sigs = sigs_of(ci)
    if MODE == "record"
        rec[i] = (fp = fp, parts = parts, w = w, sigs = sigs)
        println("R ", i, " recorded")
    else
        r = rec[i]
        hits = index_hits(r.sigs)
        caught = fp != r.fp || !isempty(hits)
        differs = w != r.w
        verdict = differs == caught ? "right" : differs ? "UNSOUND: code differs, not caught" : "imprecise: caught, code same"
        changed = join([String(k) for k in (:f1, :f2, :f3) if getfield(parts, k) != getfield(r.parts, k)], ",")
        println("K ", i, "\tcode ", differs ? "differs" : "same", "; fingerprints ", fp == r.fp ? "equal" : "differ ($changed)",
                "; index ", isempty(hits) ? "no hit" : "hit ($(join(hits, ",")))", "; ", verdict)
    end
end
MODE == "record" && serialize(FILE, rec)
