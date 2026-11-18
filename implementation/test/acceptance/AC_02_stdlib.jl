# AC-2 (old G1.5): calls into Base, LinearAlgebra and Printf from marked code
# compute plain Julia's values, and the calls at concrete signatures are recorded
# as facts: an edge at the callee (compiler §1.2).
include("ac_util.jl")
using LinearAlgebra, Printf

const m2 = [2.0 0.0; 0.0 3.0]

cdet2(m::Matrix{Float64}) = det(m)
cfmt2(m::Matrix{Float64}) = sprint(io -> (@printf(io, "%.3f", 1.0)))
mark!(cdet2)
mark!(cfmt2)

@assert cdet2(m2) == 6.0 == det(m2) "det from marked code"
@assert cfmt2(m2) == "1.000" "Printf from marked code"

ci = only([c for c in all_cis(cdet2) if c.min_world > 0 && c.owner === nothing])
# the det call's fact: an edge at det's method instance (or CodeInstance), or a (sig, callee) pair
callee_mi(e) = e isa Core.CodeInstance ? e.def : e
hasdet = any(e -> (mi = callee_mi(e); mi isa Core.MethodInstance && mi.def.name === :det), ci.edges)
@assert hasdet "det call recorded a fact edge: $(collect(ci.edges))"
@assert Compiler.decode_effects(ci.ipo_purity_bits).nortsite "no run-time site in this frame"

# the printf path reaches Printf through closures; print the census, pin the value
cif = only([c for c in all_cis(cfmt2) if c.min_world > 0 && c.owner === nothing])
println("OBSERVED cfmt edges: ", length(cif.edges), " items, rettype=", cif.rettype)

ac_finish(@__FILE__)
