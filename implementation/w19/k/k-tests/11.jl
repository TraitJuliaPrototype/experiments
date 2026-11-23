# an operation's call at a value known by its trait is split over the set's first candidates, and calls
# the members past them through a table of the call's targets
@set SpX
function spop end
ccall(:jl_set_contract_operations, Cvoid, (Any, Any), SpX,
      Core.svec(Core.svec(spop, Tuple{typeof(spop), SpX}, Int, nothing)))
struct SpC1 end; struct SpC2 end; struct SpC3 end; struct SpC4 end
struct SpM end
spop(::SpC1) = 1; spop(::SpC2) = 2; spop(::SpC3) = 3; spop(::SpC4) = 4
spop(::SpM) = 5
member!(SpX, SpC1); member!(SpX, SpC2); member!(SpX, SpC3); member!(SpX, SpC4)
member!(SpX, SpM)
spthrough(v::Vector{SpX}) = spop(v[1])

@testset "an operation's call split over its set's candidates, and the table past them" begin
    @test ccall(:jl_candidates_of, Any, (Any,), SpX) == Any[SpC1, SpC2, SpC3, SpC4, SpM]
    @test Base.return_types(spthrough, (Vector{SpX},)) == Any[Int]
    @test spthrough(SpX[SpC2()]) === 2                 # a branch of the split
    @test spthrough(SpX[SpM()]) === 5                  # past the candidates: the table
    src = first(only(code_typed(spthrough, (Vector{SpX},))))
    tested = Any[st.args[3] for st in src.code if Meta.isexpr(st, :call) && st.args[1] in (isa, GlobalRef(Core, :isa))]
    @test all(C -> C in tested, (SpC1, SpC2, SpC3, SpC4)) && !(SpM in tested)
end
