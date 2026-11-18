# W-161, E-498: open issue 150's case. `LinearAlgebra.mul!` declared an operation; a member whose own method is the
# five-argument one, so that LinearAlgebra's untyped fallback `mul!(C, A, B)` serves the three-argument operation.
# With D-4 no method at the trait hides the fallback: the membership is accepted, the fallback serves at the member,
# at a value known only by the trait and at a box; a matrix's `mul!` is untouched (no method at the set).
#     julia --project=<TraitWorld tree> op150.jl
using TraitWorld, LinearAlgebra, Test
module L
using TraitWorld, LinearAlgebra
@trait MulOp begin
    LinearAlgebra.mul!(y::Vector{Float64}, A::MulOp, x::Vector{Float64})::Vector{Float64}
end
struct Scale2; k::Float64; end
LinearAlgebra.mul!(y::Vector{Float64}, A::Scale2, x::Vector{Float64}, α::Number, β::Number) = (y .= α .* A.k .* x .+ β .* y; y)
@implement MulOp Scale2                 # served by mul!(C, A, B) = mul!(C, A, B, true, false), LinearAlgebra's fallback
apply(ops::Vector{MulOp}, x) = mul!(similar(x), ops[1], x)
end
@testset "open issue 150: an untyped fallback serves an operation" begin
    x = [1.0, 2.0]
    @test L.Scale2(1.0) isa L.MulOp
    @test mul!(similar(x), L.Scale2(2.0), x) == [2.0, 4.0]
    @test L.apply(L.MulOp[L.Scale2(3.0)], x) == [3.0, 6.0]                  # a value known only by the trait
    @test Base.return_types(L.apply, (Vector{L.MulOp}, Vector{Float64})) == [Vector{Float64}]   # the declared result
    @test mul!(similar(x), Dynamic{L.MulOp}(L.Scale2(2.0)), x) == [2.0, 4.0]  # a box
    @test isempty([m for m in methods(mul!) if m.sig isa DataType && length(m.sig.parameters) == 4 && m.sig.parameters[3] === L.MulOp])
    @test mul!(zeros(2), [1.0 0.0; 0.0 1.0], x) == x                        # a matrix: Julia's own method
end
