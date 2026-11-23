# Gate (compiler §4.8, §5.5; C-164, E-543): a membership adds no method, so code that leaves a call's choice to the
# run keeps its validity; an answer that folds that choice, or the coverage of a signature, at compile time is a
# question about a set. (1) `hasmethod(h, Tuple{AM})` at an abstract type, a set, or a union that a membership makes
# a method at the set cover is not folded where no absence edge says when it changes. (2) A call whose method is
# chosen when it runs among matches at a set is not consistent: a caller does not evaluate it at compile time at a
# constant (a singleton member) and keep the answer after the membership. A candidate for `gates/`; fails on `next`
# 2ddbe12394.
#     julia --project=experiments/implementation n44_set_choice_not_folded.jl
using Traits
@trait X44
@trait Y44
abstract type AM44 end
struct SA44 <: AM44 end
struct S44 end
struct T44 end
@implement Y44 T44
h(::X44) = :h
h2(::Union{X44, Int}) = :h2
hm_abstract() = hasmethod(h, Tuple{AM44})
hm_set() = hasmethod(h, Tuple{Y44})
hm_union() = hasmethod(h2, Tuple{Union{S44, Int}})
g(::Any) = :Any
g(::X44) = :X
Base.@nospecializeinfer q(@nospecialize(x::Y44)) = g(x)
r(x) = q(x)
Base.@nospecializeinfer qa(@nospecialize(x::Y44)) = applicable(h, x)
ra(x) = qa(x)
# (1)
@assert hm_abstract() === false && hm_set() === false && hm_union() === false
Traits.declare_membership(AM44, X44, @__MODULE__)
@assert hm_abstract() === true "hasmethod at an abstract member, compiled before: $(hm_abstract())"
Traits.declare_membership(S44, X44, @__MODULE__)
@assert hm_union() === true
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), S44, X44, @__MODULE__)
@assert hm_union() === false
Traits.declare_membership(S44, X44, @__MODULE__)
@assert hm_union() === true "hasmethod at a union, compiled after the taking back, redeclared: $(hm_union())"
# (2)
@assert r(T44()) === :Any && ra(T44()) === false
Traits.declare_membership(Y44, X44, @__MODULE__)
@assert hm_set() === true "hasmethod at a set, compiled before: $(hm_set())"
@assert r(T44()) === :X "a choice at the run folded at compile time: $(r(T44()))"
@assert ra(T44()) === true "applicable at the run folded at compile time: $(ra(T44()))"
println("n44_set_choice_not_folded: OK")
