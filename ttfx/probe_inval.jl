# E-169: what a load invalidates in the session (Julia's invalidation log), filtered to TraitWorld's code.
#     julia --project=env_d probe_inval.jl
inv = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
using TraitDifferentialEquations, TraitMakie
const TraitWorld = Base.loaded_modules[Base.PkgId(Base.UUID("7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"), "TraitWorld")]
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
println("log entries: ", length(inv))
# entries: invalidated instances, then a tag string and the cause (a Method inserted, or a signature)
tw = 0; causes = Dict{String,Int}(); last_tw = false
for (i, x) in enumerate(inv)
    if x isa Core.MethodInstance || x isa Core.CodeInstance
        mi = x isa Core.CodeInstance ? x.def : x
        mi isa Core.ABIOverride && (mi = mi.def)
        m = mi.def
        global last_tw = last_tw || (m isa Method && parentmodule(m.module) === TraitWorld || m isa Method && m.module === TraitWorld)
        m isa Method && m.module === TraitWorld && (global tw += 1)
    elseif x isa Method
        if last_tw
            k = string(x.module, ": ", first(sprint(show, x), 160))
            causes[k] = get(causes, k, 0) + 1
        end
        global last_tw = false
    end
end
println("TraitWorld instances invalidated: ", tw)
for (k, n) in sort(collect(causes); by = last, rev = true)
    println(n, "  ", k)
end
