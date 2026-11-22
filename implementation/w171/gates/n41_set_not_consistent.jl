# Gate (compiler §4.8, §3.1; E-542): compile-time evaluation runs code in the compiler's world and records only an
# edge to the callee's code. An answer about a set that inference does not fold, and a call given a set as a constant
# (`typeintersect`, `==` of types), answer by the world's memberships: no caller folds them. Each function is compiled
# before the membership and called after it; a typeassert's caller does not run into `unreachable` (the process
# stops on a build without the rule).
# A candidate for `gates/`; fails on `next` dd42dc8c3f, passes on `w171`.
#     julia --project=experiments/implementation n41_set_not_consistent.jl
using Traits
@trait X
struct S end
const TS = Tuple{S}
const TX = Tuple{X}
const L1 = Ref{T} where T>:X
const L2 = Ref{T} where T>:Union{X, S}
q_sub() = TS <: TX
r_sub() = q_sub()
q_int() = typeintersect(S, X) === Union{}
r_int() = q_int()
q_eq() = L1 == L2
r_eq() = q_eq()
q_tas(x) = (x::X; true)
r_tas(x) = q_tas(x)
call(f, a...) = try f(a...) catch e; nameof(typeof(e)) end
@assert (r_sub(), r_int(), r_eq(), call(r_tas, S())) == (false, true, false, :TypeError)
@implement X S
@assert (r_sub(), r_int(), r_eq()) == (true, false, true) "callers compiled before the membership: $((r_sub(), r_int(), r_eq()))"
@assert call(r_tas, S()) === true
println("n41_set_not_consistent: OK")
