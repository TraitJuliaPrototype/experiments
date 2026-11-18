# AC-10 (old G1.33): an assertion over a call with MORE MATCHING METHODS THAN
# MAX_METHODS records no edge (plain records none there either), so it is a
# run-time site as well: in code compiled by facts the assertion does not apply,
# and the value follows the redefinition (under the test bed); in the product
# setting the asserted helper is plain code, and the marked value is plain's.
include("ac_util.jl")

gm() = 0
gm(a::Int) = 1
gm(a::Int, b::Int) = 2
gm(a::Int, b::Int, c::Int) = 3
gm(a::Int, b::Int, c::Int, d::Int) = 4
Base.@assume_effects :foldable hm(n::Int) = gm((Base.inferencebarrier((1, 1))::Tuple{Vararg{Int}})...)
k10() = hm(1)
k10p() = hm(1)
mark!(k10)

m0p, m0 = k10p(), k10()
gm(a::Int, b::Int) = 20
m1p, m1 = k10p(), k10()
println("OBSERVED plain: $m0p -> $m1p")
# In the product setting `hm` is a neutral method, compiled plainly whoever calls it (facts §6.2):
# the marked caller rests on plain inference's answer, the same as plain Julia's (G1). Under the
# test bed `hm` is compiled by facts for its facts caller, where the assertion over the run-time
# site does not apply (facts §8), and the value follows the redefinition.
@assert m0 == m0p && m1 == m1p "G1.33: the marked value is plain Julia's: $m0 -> $m1 against $m0p -> $m1p"
AC_TESTBED && @assert m0 == 2 && m1 == 20 "G1.33: under the test bed the marked value follows the redefinition: $m0 -> $m1"

ac_finish(@__FILE__)
