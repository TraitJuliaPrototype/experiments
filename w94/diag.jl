# W-94 (open issue 126): why a member fold of Tables' image is rejected when CSV loads.
#     julia --project=<env> diag.jl [Pkg,Pkg,…]
# Loads the packages with the compiler's validation log on; for each FoldRecord that failed, evaluates
# the fold's steps again: the registry entry, the image records found for the member, and for each record
# which of its signatures select other methods now, with the methods then and now.
R = Base.Compiler.ReinferUtils
R.debug_method_invalidation(true)
pkgs = Symbol.(split(get(ARGS, 1, "Tables,CSV"), ","))
for p in pkgs
    n0 = length(R._jl_debug_method_invalidation[])
    Base.require(Main, p)
    println("loaded ", p, ": log entries ", length(R._jl_debug_method_invalidation[]) - n0)
end
log = R._jl_debug_method_invalidation[]
R.debug_method_invalidation(false)
using TraitWorld
const TW = TraitWorld
const CC = Base.Compiler
fails = Any[]
for i in eachindex(log)
    log[i] == "insert_backedges_callee" || continue
    e = log[i-1]
    e isa CC.FoldRecord && push!(fails, (e, log[i+1]))
end
println("failed fold records: ", length(fails))
seen = Set{Any}()
for (rec, ci) in fails
    reg, X, U = rec.args
    (X, U) in seen && continue
    push!(seen, (X, U))
    println("\n== ", X, " at ", U, "   (code: ", ci.def isa Core.MethodInstance ? ci.def : ci.def.def, ")")
    w = Base.get_world_counter()
    now = Base.invoke_in_world(w, TW._member_fold, CC.AtLoad(), reg, X, U)
    println("  stored value ", typeof(rec.value), "; value now ", typeof(now), "; egal ", rec.value === now)
    ms = Base._methods_by_ftype(Tuple{typeof(TW._member_record),Type{X},Type{U},Any}, -1, w)
    println("  image records found: ", ms isa Vector ? length(ms) : ms)
    ms isa Vector || continue
    for m in ms
        K = Base.unwrap_unionall(m.method.sig).parameters[4]
        r = Base.invoke_in_world(w, TW._member_record, X, U, K.instance)
        println("  record of ", K, ": builder egal to stored value: ", r.builder === rec.value,
                "; holds now: ", TW._record_holds(r, w))
        for j in eachindex(r.sigs)
            now_ms = TW._selected_methods(r.sigs[j], w)
            now_ms == r.methods[j] && continue
            println("    signature ", r.sigs[j])
            println("      then: ", join(string.(r.methods[j]), "\n            "))
            println("      now:  ", join(string.(now_ms), "\n            "))
        end
    end
end
