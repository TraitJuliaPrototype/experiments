using TraitWorld
const C = Core.Callable
struct OP{T,F<:C{Tuple{Vector{T}},Nothing},J<:C{Tuple{Matrix{T}},Nothing}}
    f::F
    u0::Vector{T}
    jac::J
end
for m in methods(OP); println(m); end
