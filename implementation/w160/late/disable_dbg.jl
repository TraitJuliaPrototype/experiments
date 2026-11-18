# W-160 (c): what the `jl_method_table_disable` entries at the ODE port's load are (E-404's 92, E-439)
inv = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
using TraitDifferentialEquations
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
for i in eachindex(inv)
    x = inv[i]
    x isa String && x == "jl_method_table_disable" || continue
    m = inv[i-1]
    if m isa Method
        println("REPLACED METHOD ", m.module, ".", m.name, " ", m.sig, " primary_world=", m.primary_world, " dispatch_status=", m.dispatch_status)
    else
        println("  an instance: ", m, m isa Core.MethodInstance ? string(" cache owner ", isdefined(m, :cache) ? m.cache.owner : "-", " worlds ", isdefined(m, :cache) ? (m.cache.min_world, m.cache.max_world) : "") : "")
    end
end
