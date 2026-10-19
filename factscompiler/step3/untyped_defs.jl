using TraitWorld
# Step 3: a bounded function called with an argument of unknown type (from a Vector{Any}), against
# the same plain function called the same way, and typed calls of both.
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
