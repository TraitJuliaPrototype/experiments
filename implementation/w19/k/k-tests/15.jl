# an operation's declared result is not checked by the member's own code: the call through the trait marks
# its result trusted and checks it, so a member whose method returns another type raises a `TypeError` there
@set TrX
function trop end
ccall(:jl_set_contract_operations, Cvoid, (Any, Any), TrX,
      Core.svec(Core.svec(trop, Tuple{typeof(trop), TrX}, Int, nothing)))
struct TrM end
trop(::TrM) = 1
member!(TrX, TrM)
trthrough(v::Vector{TrX}) = trop(v[1])
trdyn(v::Vector{Any}) = trop(v[1])
@test trthrough(TrX[TrM()]) === 1
trop(::TrM) = UInt(2)                                  # the member's method, redefined to another type

@testset "an operation's result is checked where the member's code does not check it" begin
    @test Base.return_types(trthrough, (Vector{TrX},)) == Any[Int]
    @test Base.infer_effects(trthrough, (Vector{TrX},)).trusted != 0
    @test_throws TypeError trthrough(TrX[TrM()])
    @test trdyn(Any[TrM()]) === UInt(2)                # a dynamic call returns the member's own result
end
