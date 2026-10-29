# E-245: a bound's `where` variable named as a global of the trait module (LinearAlgebra's `I` in ODECore):
# plain Julia shadows the global; does TraitWorld's lowering?
using TraitWorld
@trait_module module Shadow
using TraitWorld
using LinearAlgebra: I
export Ix, ixof, plainof
@trait Ix{K} begin
    key(x::Ix{K})::Int
end
struct A; end
@implement Ix{Symbol} A begin
    key(a) = 1
end
ixof(x::Ix{I}) where {I} = I            # the where variable I shadows LinearAlgebra's I in plain Julia
plainof(x::Vector{I}) where {I} = I
end
using .Shadow
println("plain: ", Shadow.plainof([1.0]))
try
    println("bound: ", Shadow.ixof(Shadow.A()))
catch e
    println("bound: ", typeof(e), ": ", first(sprint(showerror, e), 300))
end
