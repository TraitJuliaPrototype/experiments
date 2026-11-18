# Gate (W-100, slice 4; compiler §1.4): `return_type` gives plain inference's answer under either
# policy: in code compiled by facts it folds only an answer that cannot be wider (a constant, a
# concrete type, Union{}), and otherwise asks at run time, where every method is inferred plainly.
include("util.jl")
module FM
Base.Experimental.@compiler_options facts=true
p(x::Int) = 1
p(x::Float64) = 2.0
mapped(v::Vector{Real}) = map(p, v)            # map's eltype from return_type at Real
collected(v::Vector{Real}) = [p(x) for x in v]
concrete(v::Vector{Int}) = map(p, v)
end
plainmapped(v::Vector{Real}) = map(FM.p, v)
v = Real[1, 2.0]
@assert typeof(FM.mapped(v)) == typeof(plainmapped(v))
@assert typeof(FM.collected(v)) == typeof([FM.p(x) for x in v])
@assert typeof(FM.concrete([1, 2])) == Vector{Int}
@assert typeof(FM.mapped(Real[])) == typeof(plainmapped(Real[]))   # empty: return_type alone decides
@assert Core.Compiler.return_type(FM.p, Tuple{Real}) == Union{Int, Float64}
println("f5_return_type: OK")
