# W-140, the abstract-type case (compiler C-88): Main marked as loaded, so that a pair of an abstract
# type and a set of Main is settled, as it is for a loaded package's.
ccall(:jl_module_set_loaded, Cvoid, (Any,), Main)
using Traits
@trait PX
@implement PX Vector{Int}
final(S, X) = ccall(:jl_membership_final, Cint, (Any, Any), S, X)
@show final(AbstractVector, PX) final(AbstractVector{Int}, PX) final(AbstractVector{Float64}, PX) final(AbstractString, PX)
@show typeintersect(AbstractVector, PX)
f(::Any) = :any
f(::PX) = :px
g(@nospecialize(x::AbstractVector)) = f(x)
@show g(Int[1]) g(Float64[1])
@show Base.code_typed(g, (AbstractVector,))
