# E-367 (W-141), review of 2026-11-12: the entry and the method are two records. Asks what is left of
# the method where the runtime refuses the membership after the method is added to the table:
# a second instance for a member (compiler §4.6), written by hand.
# Run from experiments/unification: JULIA_LOAD_PATH="$PWD:@stdlib" julia --startup-file=no w141/probe_refused.jl
using Traits
@trait HQ{N, R}
struct S end
@implement HQ{:a, Int} S
sig = Tuple{typeof(Core.implements), Type{HQ{:b, String}}, Type{S}}
err = try @eval(Core.implements(::Type{HQ{:b, String}}, ::Type{S}) = nothing); nothing catch e; e end
println("refused: ", err === nothing ? "NO" : sprint(showerror, err))
println("S <: HQ{:b, String}: ", S <: HQ{:b, String})
println("methods at the pair: ", length(methods(Core.implements, Tuple{Type{HQ{:b, String}}, Type{S}})))
println("hasmethod: ", hasmethod(Core.implements, Tuple{Type{HQ{:b, String}}, Type{S}}))
n = 0
Base.visit(Core.methodtable) do m
    m.sig === sig && (global n += 1; println("in the table: ", m, " primary_world ", m.primary_world, " dispatch_status ", m.dispatch_status))
end
println("entries of the table at the signature: ", n)
