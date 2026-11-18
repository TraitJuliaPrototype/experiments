# W-81 (open issue 82, option (a)): a stored value's capability selected at a bound (traits §6.5)
using TraitWorld
@trait_module module Cap
using TraitWorld
export Col, Pooled, ncells, codes, kind, Shape, area
@trait Col begin
    ncells(c::Col)::Int
end
@trait Pooled begin                      # a capability: a trait of its own, not a subtrait
    codes(c::Pooled)::Vector{Int}
end
@trait Shape begin
    area(s::Shape)::Float64
end
kind(c::Col) = :plain
kind(c::(Col, Pooled)) = :pooled
end
using .Cap
struct PlainCol; v::Vector{Float64}; end
struct PoolCol; c::Vector{Int}; end
@implement Col PlainCol begin ncells(c) = length(c.v) end
@implement Col PoolCol begin ncells(c) = length(c.c) end
@implement Pooled PoolCol begin codes(c) = c.c end
struct Circle; r::Float64; end
@implement Shape Circle begin area(s) = pi * s.r^2 end
cols = Dynamic{Col}[Dynamic{Col}(PlainCol([1.0, 2.0])), Dynamic{Col}(PoolCol([1, 1, 2]))]
println("C ", [kind(c) for c in cols], " ([:plain, :pooled])")
r = try; kind(Dynamic{Shape}(Circle(1.0))); "accepted"; catch e; "refused: " * first(sprint(showerror, e), 170); end
println("C ", r)
# T-54: a kept function at another signature, checked at the bound
@trait_module module Sig
using TraitWorld
callf(f::Callable{Tuple{Float64}, Float64}, x::Float64) = f(x)
calli(f::Callable{Tuple{String}, Int}, s::String) = f(s)
end
g = Dynamic{Callable{Tuple{Int}, Int}}(x -> 2x)
println("C ", Sig.callf(g, 1.5), " (3.0: a method at Float64)")
r = try; Sig.calli(g, "a"); "accepted"; catch e; "refused: " * first(sprint(showerror, e), 170); end
println("C ", r)
