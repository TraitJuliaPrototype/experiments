# E-321: what invalidates ForwardDiff's code at setting D's load (insertions and image validation).
#   cd experiments/ttfx && julia --project=../unification/e289/env_d_unified invalidations_d.jl
ins = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
val = Base.Compiler.ReinferUtils.debug_method_invalidation(true)
using TraitDifferentialEquations, TraitMakie, TraitWorld
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
Base.Compiler.ReinferUtils.debug_method_invalidation(false)
println("insertion log: ", length(ins), " entries; validation log: ", length(val), " entries")
# insertion log: runs of MethodInstances then a cause (a Method and a tag, or a membership)
function runs(log)
    out = Any[]; cur = Any[]
    for x in log
        if x isa Core.MethodInstance || x isa Core.CodeInstance
            push!(cur, x)
        elseif x isa Integer
            continue
        else
            push!(out, (x, cur)); cur = Any[]
        end
    end
    isempty(cur) || push!(out, (:tail, cur))
    out
end
mods(v) = unique(string(parentmodule(x isa Core.CodeInstance ? x.def.def : x.def)) for x in v if (x isa Core.MethodInstance ? x.def : x.def.def) isa Method)
for (cause, v) in runs(ins)
    any(occursin("ForwardDiff", string(x)) for x in v) || continue
    println("INSERT cause ", first(sprint(show, cause), 200), "  -> ", length(v), " instances; e.g. ", first(string(v[1]), 160))
end
let n = 0
    for (i, x) in enumerate(val)
        s = string(x)
        if occursin("ForwardDiff", s) && (x isa Core.MethodInstance || x isa Core.CodeInstance)
            n += 1
            n <= 12 && println("VALIDATE ", first(s, 200), "  next: ", first(string(get(val, i + 1, "")), 160), " | ", first(string(get(val, i + 2, "")), 160))
        end
    end
    println("ForwardDiff entries in the validation log: ", n)
end
