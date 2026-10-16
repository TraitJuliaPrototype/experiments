using TraitDifferentialEquations
const TDE = TraitDifferentialEquations
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
using CSV, DataFrames, CairoMakie
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
inTW(mi) = mi isa Core.MethodInstance && mi.def isa Method && (mi.def.module === TDE.ODECore || mi.def.module === TDE || parentmodule(mi.def.module) === TDE)
i = 1; chain = Any[]
reasons = ("jl_method_table_insert", "jl_method_table_disable", "insert_backedges_callee", "verify_methods", "invalidate_mt_cache", "insert_backedges")
for (k, x) in enumerate(log)
    if x isa String && x in reasons
        trig = log[k-1]
        if any(inTW, chain)
            root = first(y for y in chain if y isa Core.MethodInstance)
            tw = [string(y.def.name) for y in chain if inTW(y)]
            println("trigger: ", first(string(trig), 160), " [", x, "]")
            println("  root (edge holder) specTypes: ", first(string(root isa Core.MethodInstance ? root.specTypes : root), 200))
            println("  concrete root sig: ", root isa Core.MethodInstance && isconcretetype(root.specTypes), "; trait-world: ", unique(tw))
        end
        empty!(chain)
    elseif !(x isa Int)
        push!(chain, x)
    end
end
