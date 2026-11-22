# W-171 (E-542): a typeassert at a set, compiled before a membership, through a caller: the caller evaluated the callee
# at compile time (its effects claimed consistency), so the typeassert's throw was folded and the code ran into
# `unreachable` after the membership.
#     julia --project=experiments/implementation tassert_inline.jl
using Traits
@trait X
struct S end
const B = X
q(x) = (x::B; true)
r(x) = q(x)
cis(f) = [(Int(c.min_world), c.max_world == typemax(UInt) ? "∞" : Int(c.max_world), c.rettype) for mi in Base.specializations(only(methods(f))) for c in (mi.cache,)]
call(f, a...) = try f(a...) catch e; nameof(typeof(e)) end
println("r: ", call(r, S()), " q: ", call(q, S()))
println("r ", cis(r), " q ", cis(q))
@implement X S
println("after: q ", cis(q), " r ", cis(r))
println("q: ", call(q, S()))
println("after q: q ", cis(q), " r ", cis(r))
