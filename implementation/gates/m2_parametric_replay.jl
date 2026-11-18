# Gate for compiler C-72 (the walk's scope): a membership at a parametric set reaches the
# methods at `X{T}` whose `T` is a method variable, by the walk's substituted path; a method
# at another instance of the set is left alone. Each call is made and cached before the
# membership, through a compiled call site, then asked in the new world and the old one.
using Traits
include("util.jl")

@trait PR{T}
struct RM end                 # joins PR{Int}
struct RB end                 # joins every instance (a pattern's instance)

pr(::PR{T}) where {T} = (:set, T)          # the set's parameter a method variable
pr(::Any) = :any
pc(c::C) where {T, C <: PR{T}} = :setc     # a variable whose bound names the set
pc(::Any) = :any
po(::PR{String}) = :other                  # another instance than the member's
po(::Any) = :any
pd(a::PR{T}, b::T) where {T} = :diag       # a second argument bound by the set's parameter
pd(a, b) = :any2
pq(::PR{T}) where {T} = :setq              # for the member of every instance
pq(::Any) = :any

site_r(x) = pr(x); site_c(x) = pc(x); site_o(x) = po(x); site_d(x, y) = pd(x, y); site_q(x) = pq(x)

@assert site_r(RM()) === :any && site_c(RM()) === :any && site_o(RM()) === :any
@assert site_d(RM(), 1) === :any2 && site_d(RM(), "s") === :any2
@assert site_q(RB()) === :any
fs = Any[pr, pc, po, pq]; args = Any[RM(), RM(), RM(), RB()]   # dynamic calls: the leaf and typemap caches
@assert [Base.inferencebarrier(fs[i])(args[i]) for i in 1:4] == Any[:any, :any, :any, :any]
w_pre = curworld()

@implement PR{Int} RM
@implement PR RB

@assert site_r(RM()) === (:set, Int) "X{T} with T a method variable: the set method in the new world"
@assert site_c(RM()) === :setc "C <: X{T}: the set method in the new world"
@assert site_o(RM()) === :any "another instance: unchanged"
@assert site_d(RM(), 1) === :diag "T bound by the member's instance"
@assert site_d(RM(), "s") === :any2 "and not past it"
@assert site_q(RB()) === :setq "a member of every instance"
@assert Base.invoke_in_world(w_pre, site_r, RM()) === :any "the old world keeps its answer"
@assert Base.invoke_in_world(w_pre, site_c, RM()) === :any
@assert Base.invoke_in_world(w_pre, site_d, RM(), 1) === :any2
@assert Base.invoke_in_world(w_pre, site_q, RB()) === :any
# the same dynamic calls, whose cache entries the walk lowers
@assert [Base.inferencebarrier(fs[i])(args[i]) for i in 1:4] == Any[(:set, Int), :setc, :any, :setq]
println("m2_parametric_replay: OK")
