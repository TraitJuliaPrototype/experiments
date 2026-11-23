# a closed build's check in a session: the program's calls of an operation at a set are split over the
# members it has, a family's by the instances the program uses
@set CbX
function cbop end
ccall(:jl_set_contract_operations, Cvoid, (Any, Any), CbX,
      Core.svec(Core.svec(cbop, Tuple{typeof(cbop), CbX}, Int, nothing)))
struct CbA end
struct CbF{T} end
cbop(::CbA) = 1
cbop(::CbF) = 2
member!(CbX, CbA)
member!(CbX, let T = TypeVar(:T); UnionAll(T, CbF{T}) end)
cbuse(v::Vector{CbX}) = cbop(v[1])
cbmain() = cbuse(CbX[CbA()]) + cbuse(CbX[CbF{Int}()])
@test cbmain() == 3

@testset "a closed build's check: the members of a set are those the program has" begin
    mi = Base.method_instance(cbmain, ())
    errors, parents, members, rounds = Base.Compiler.closed_check(Any[mi], Base.get_world_counter())
    @test isempty([e for (warn, e) in errors if !warn])
    found = Dict{Any,Vector{Any}}(members)
    @test haskey(found, CbX) && Set(found[CbX]) == Set(Any[CbA, CbF{Int}])
    @test rounds >= 1
end
