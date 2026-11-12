# E-367, stage 1 (W-141), R4, R5, R7: what the runtime pays per membership and per folded negative,
# on the build with a method per membership and on the build before it (cells). No library: the
# runtime's own entry point. Run: julia --startup-file=no costs.jl [N]
const N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 2000
using Traits                      # the gates' shim: sets and memberships only
declare(S, X) = ccall(:jl_declare_membership, Any, (Any, Any, Any, Any, Any), S, X, Main, nothing, :self)
@trait XBig
@trait YNeg
@trait ZSmall
const X = XBig; const Y = YNeg; const Z = ZSmall
println("build: ", isdefined(Core, :implements) ? "a method per membership" : "cells")

# (1) N members of one set: the declaration
structs = [Core.eval(Main, :(struct $(Symbol(:M, i)) end; $(Symbol(:M, i)))) for i in 1:N]
t = @elapsed for S in structs[1:N÷2]; declare(S, X); end
t2 = @elapsed for S in structs[N÷2+1:N]; declare(S, X); end
println("declare: first ", N ÷ 2, " members ", round(t / (N ÷ 2) * 1e6; digits = 1), " us each; next ", N - N ÷ 2, " ",
        round(t2 / (N - N ÷ 2) * 1e6; digits = 1), " us each")

# (2) N folded negatives at one set: each a function compiled at a type that is no member of Y
others = [Core.eval(Main, :(struct $(Symbol(:O, i)) end; $(Symbol(:O, i)))) for i in 1:N]
@eval isy(x) = x isa $Y
precompile(isy, (Int,))
t = @elapsed for S in others[1:N÷2]; precompile(isy, (S,)); end
t2 = @elapsed for S in others[N÷2+1:N]; precompile(isy, (S,)); end
println("fold a negative: first ", N ÷ 2, " ", round(t / (N ÷ 2) * 1e6; digits = 1), " us each; next ", N - N ÷ 2, " ",
        round(t2 / (N - N ÷ 2) * 1e6; digits = 1), " us each (inference included)")
@assert isy(others[1]()) === false

# (3) a membership with N negatives folded at its set, and one at another set
t = @elapsed declare(others[1], Y)
println("declare at the set with ", N, " folded negatives: ", round(t * 1e6; digits = 1), " us")
@assert isy(others[1]()) === true && isy(others[2]()) === false
struct Fresh end
t = @elapsed declare(Fresh, X)
println("declare a fresh type at the set with ", N, " members: ", round(t * 1e6; digits = 1), " us")
t = @elapsed declare(Fresh, Z)
println("declare at a new set: ", round(t * 1e6; digits = 1), " us")

# (4) plain code: subtyping and a method definition with no set in them (R7)
struct P1 end
abstract type PA end
t = @elapsed for _ in 1:10^6; P1 <: PA; end
println("a plain subtype query: ", round(t * 1e3; digits = 1), " ns")
f(::Int) = 1
t = @elapsed for i in 1:200; @eval f(::Val{$i}) = $i; end
println("a plain method definition: ", round(t / 200 * 1e6; digits = 1), " us")
