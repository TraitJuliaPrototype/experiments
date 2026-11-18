# Gate (W-100, slice 1; compiler §1.1–§1.3, §1.5): under the facts mode a call is inferred only at a
# fact signature; every other call is a run-time site, typed Any, clearing `nortsite`, which its
# callers carry; an asserted effect does not apply over it. Plain inference is unchanged.
const CC = Core.Compiler
include("util.jl")

p(x::Int) = 1
p(x::Float64) = 2.0
q(x::Real) = p(x)
r(x::Int) = q(x)
Base.@assume_effects :foldable s(x::Real) = p(x)

facts = CC.NativeInterpreter(; facts = true)
plain = CC.NativeInterpreter()
@assert CC.facts_mode(facts) && !CC.facts_mode(plain)

# at a fact signature: inferred, no run-time site
@assert Base.code_typed(q, (Int,); interp = facts)[1][2] === Int
@assert CC.is_nortsite(Base.infer_effects(q, (Int,); interp = facts))
# at a signature that is not a fact: a run-time site
@assert Base.code_typed(q, (Real,); interp = facts)[1][2] === Any
@assert !CC.is_nortsite(Base.infer_effects(q, (Real,); interp = facts))
@assert Base.code_typed(q, (Real,); interp = plain)[1][2] === Union{Int, Float64}
# a union of concrete types splits into facts
@assert Base.code_typed(q, (Union{Int, Float64},); interp = facts)[1][2] === Union{Int, Float64}
# an asserted effect does not apply over a run-time site
@assert !CC.is_foldable(Base.infer_effects(s, (Real,); interp = facts))
@assert CC.is_foldable(Base.infer_effects(s, (Real,); interp = plain))
println("f1_facts_sites: OK")
