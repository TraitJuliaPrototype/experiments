# a positive answer through entries records the entries of both sides, each variable's lower and upper
# bound included: in `Tuple{S, Ref{Y}} <: Tuple{Z, Ref{T}} where T >: X` the answer rests on `S in Z` and
# on `X in Y`, the second's member in the right side's lower bound
@set EnZ
@set EnX
@set EnY
struct EnS end
const EnA = Tuple{EnS, Ref{EnY}}
const EnB = let T = TypeVar(:T, EnX, Any); UnionAll(T, Tuple{EnZ, Ref{T}}) end
const EnA3 = let T = TypeVar(:T, EnY, Any); UnionAll(T, Tuple{EnS, Ref{T}}) end
const EnA1 = Ref{EnY}
const EnB1 = let T = TypeVar(:T, EnX, Any); UnionAll(T, Ref{T}) end
enp() = EnA <: EnB
enp3() = EnA3 <: EnB
enp1() = EnA1 <: EnB1
enfresh(a, b) = Base.inferencebarrier(a) <: Base.inferencebarrier(b)
en_edges(ci) = Any[e.def for e in ci.edges if e isa Core.MethodInstance && e.def isa Method && e.def.name === :implements]
en_folded(f) = only(code_typed(f, ())).first.code[end] == Core.ReturnNode(true)
const ene1 = member!(EnZ, EnS)
const ene2 = member!(EnY, EnX)

@testset "a positive answer through entries records the entries of both sides" begin
    @test EnA <: EnB && EnA3 <: EnB && EnA1 <: EnB1
    @test !Base.invoke_in_world(ene2.min_world - 1, enfresh, EnA, EnB)
    for f in (enp, enp3, enp1)
        @test f()
        ci = Base.method_instance(f, ()).cache
        if en_folded(f)
            @test ene2.method in en_edges(ci)
            f === enp1 || @test ene1.method in en_edges(ci)
            @test ci.min_world >= ene2.min_world
        end
        @test !Base.invoke_in_world(ene2.min_world - 1, f)
    end
end

ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), EnX, EnY, @__MODULE__)

@testset "a positive answer through a lower bound's entry, taken back" begin
    @test !(EnA <: EnB)
    @test (enp(), enp3(), enp1()) == (false, false, false)
end
