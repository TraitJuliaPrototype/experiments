# E-180: with TraitWorld's cache on, run a workload and report what the session still compiled: the parts' counts,
# and the new CodeInstances by owner, by whether they name the session's types, and whether the store has them.
#     JULIA_TW_CACHE=1 JULIA_TW_CACHE_BUILD=off JULIA_TW_CACHE_DIR=... julia --project=env_d cache/probe_k.jl workload_d.jl out/png
const _SCRIPT, _OUT = ARGS[1], ARGS[2]
empty!(ARGS); push!(ARGS, _OUT)
include(joinpath(@__DIR__, "..", _SCRIPT))
let TW = Base.loaded_modules[only(filter(k -> k.name == "TraitWorld", collect(keys(Base.loaded_modules))))]
    for (id, m) in Base.loaded_modules
        startswith(id.name, "TWC_") && println("K part ", id.name, " ", getglobal(m, :COUNTS))
    end
    mods = TW._cache_image_modules()
    known = TW._cache_known(TW._CACHE_DIR[])
    tally = Dict{Any,Int}()
    for ci in TW._CACHE_NEW
        ci isa Core.CodeInstance || continue
        mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
        mi.def isa Method || continue
        deps = Set{Base.PkgId}()
        ok = TW._cache_deps!(deps, mi.def.module, mods) && TW._cache_deps!(deps, mi.specTypes, mods)
        h = ok ? hash(TW._cache_blob(ci.owner === :facts ? :facts : :plain, mi.specTypes)) : UInt(0)
        k = (ci.owner, ok ? (h in known ? "in store" : "new") : "names the session")
        tally[k] = get(tally, k, 0) + 1
        get(ENV, "PROBE_LIST", "0") == "1" && ok && h in known && println("K again ", ci.owner, " ", mi.specTypes)
    end
    for (k, v) in sort!(collect(tally); by = string); println("K ", k, " ", v); end
end
