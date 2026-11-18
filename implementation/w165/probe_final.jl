# Probe: the final-pair test for (AbstractString, Callable instance) and (AbstractString, bare Z)
using Traits
@trait Z{P}
C1 = Core.Callable{Tuple{Int},Int}
for (a, b) in ((AbstractString, C1), (AbstractString, Core.Callable), (AbstractString, Z), (AbstractString, Z{1}))
    println(a, " / ", b, ": closed_after_load=", ccall(:jl_is_closed_after_load, Cint, (Any,), b),
            " could_join ab=", ccall(:jl_could_join, Cint, (Any, Any), a, b), " ba=", ccall(:jl_could_join, Cint, (Any, Any), b, a),
            " final=", ccall(:jl_membership_final, Cint, (Any, Any), a, b),
            " cells=", ccall(:jl_membership_final_cells, Any, (Any, Any), a, b))
end
for T in (Tuple{Int, Core.All{Tuple{AbstractString, C1}}}, Tuple{Int, typeintersect(AbstractString, Core.Callable)}, Tuple{Int, typeintersect(AbstractString, Z)})
    println(T, ": unmet=", ccall(:jl_has_unmet_argument, Cint, (Any, UInt), T, Base.get_world_counter()), " cells=", ccall(:jl_unmet_final_cells, Any, (Any,), T))
end
