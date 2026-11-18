# Gate (compiler §4.8; found by the ODE port's front end, E-373): a test `x isa X` at a set narrows
# the value to the set where it holds, since the test proves it when it runs. No negative is folded:
# the other branch keeps what was known, and a type that could still join the set is not dropped
# from the true branch. So a result annotation at a trait, `f(…)::X`, is inferred as `X`, and a
# membership declared later changes no answer.
using Traits
include("util.jl")
rt(f, T) = only(Base.return_types(f, T))

module P27
using Traits
@trait Shape
struct Circle; r::Float64; end
struct Late; r::Float64; end                  # joins Shape late
end
using .P27: Shape, Circle, Late
declare_membership(Circle, Shape, @__MODULE__)

# a result annotation at the trait: the result is the trait's, not Any
made(v::Vector{Any})::Shape = v[1]
@assert rt(made, (Vector{Any},)) === Shape "f(…)::X is inferred as X: $(rt(made, (Vector{Any},)))"
kmade(v::Vector{Any}; k = 1)::Shape = v[k]
@assert rt(kmade, (Vector{Any},)) === Shape "with keywords: $(rt(kmade, (Vector{Any},)))"
@assert made(Any[Circle(1.0)]) === Circle(1.0)
@assert try made(Any[1]); false catch e; e isa Union{MethodError, TypeError} end "a value outside the set is refused"

# a test narrows the true branch to the set; the false branch keeps what was known
narrow(x) = x isa Shape ? x : nothing
@assert rt(narrow, (Any,)) === Union{Nothing, Shape} "the true branch is the set: $(rt(narrow, (Any,)))"
other(x) = x isa Shape ? nothing : x
@assert rt(other, (Any,)) === Any "the false branch folds no negative: $(rt(other, (Any,)))"

# a value known as one of two types, one of which could still join: neither is dropped
pick(x::Union{Circle, Late}) = x isa Shape ? x : nothing
r = rt(pick, (Union{Circle, Late},))
@assert Late <: r && Circle <: r "a type that could join is not dropped from the true branch: $r"
@assert pick(Late(1.0)) === nothing && pick(Circle(1.0)) === Circle(1.0)
declare_membership(Late, Shape, @__MODULE__)
@assert pick(Late(1.0)) === Late(1.0) "a membership declared later is followed"
@assert narrow(Late(2.0)) === Late(2.0) && made(Any[Late(3.0)]) === Late(3.0)

println("n31_isa_narrows: OK")
