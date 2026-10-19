# Step 3: a bounded function called with an argument of unknown type (from a Vector{Any}), against
# the same plain function called the same way, and typed calls of both.
#     julia --project=<env with TraitWorld, BenchmarkTools> untyped.jl
using TraitWorld, BenchmarkTools
@trait_module module UT
using TraitWorld
export Sampled, rmean
@trait Sampled begin
    @const data::Vector{Float64}
end
rmean(s::Sampled) = s.data[1]
end
using .UT
struct SA; name::String; data::Vector{Float64}; end
@implement UT.Sampled SA
struct SB; data::Vector{Float64}; n::Int; end
@implement UT.Sampled SB
pmean(s) = s.data[1]                        # the plain twin
const XS = Any[SA("a", [1.0, 2.0]), SB([3.0], 1)]
untyped_t(xs) = (s = 0.0; for x in xs; s += UT.rmean(x)::Float64; end; s)
untyped_p(xs) = (s = 0.0; for x in xs; s += pmean(x)::Float64; end; s)
typed_t(x, n) = (s = 0.0; for _ in 1:n; s += UT.rmean(x); end; s)
typed_p(x, n) = (s = 0.0; for _ in 1:n; s += pmean(x); end; s)
untyped_t(XS); untyped_p(XS)
get(ENV, "SHOWIR", "") == "1" && (display(code_typed(typed_t, (SA, Int))[1]); exit())
ns(t, n) = round(1e9 * t / n; digits = 1)
println("untyped, trait   ", ns(@belapsed(untyped_t($XS)), 2), " ns/call")
println("untyped, plain   ", ns(@belapsed(untyped_p($XS)), 2), " ns/call")
println("typed, trait     ", ns(@belapsed(typed_t($(XS[1]), 1000)), 1000), " ns/call")
println("typed, plain     ", ns(@belapsed(typed_p($(XS[1]), 1000)), 1000), " ns/call")
println("allocations per untyped trait call: ", (untyped_t(XS); @allocated(untyped_t(XS)) / 2), " bytes")
