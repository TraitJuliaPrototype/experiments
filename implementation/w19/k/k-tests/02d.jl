# a set that occurs only as a type variable's lower bound: subtyping walks the bound, so a membership
# decides the question there, and the bit "a set occurs in this type" must see it
@set XLB
struct LBM end
const LBU = Union{XLB, LBM}                                    # made before the membership
const LBA = let S = TypeVar(:S, XLB, Any); UnionAll(S, Ref{S}) end   # Ref{S} where S >: XLB
const LBB = let S = TypeVar(:S, LBU, Any); UnionAll(S, Ref{S}) end   # Ref{S} where S >: Union{XLB, LBM}
lbq() = LBA <: LBB                                             # compiled before the membership
@test !lbq()
member!(XLB, LBM)

@testset "a set in a type variable's lower bound" begin
    @test ccall(:jl_has_open_set, Cint, (Any,), LBA) == 1
    @test ccall(:jl_has_open_set, Cint, (Any,), Vector{LBA}) == 1
    @test LBA == LBB
    @test lbq()
end

# whether a membership could change a negative about a set: a Vararg tail, `Type{S}` against a type
# that is no set, a parameter reached through a declared supertype
@set VaX
struct VaS end
abstract type VaAP{T} end
struct VaP{T} <: VaAP{T} end
const VaV1 = Tuple{Int, VaS, VaS}
const VaV2 = Tuple{Int, Vararg{VaX}}
vaqv() = VaV1 <: VaV2
vaqt() = VaS isa Type{<:VaX}
vaqp() = VaP{VaS} <: VaAP{<:VaX}
vaqa(x) = (x::VaV2; true)
vacall(f, a...) = try f(a...) catch e; nameof(typeof(e)) end
@test (vaqv(), vaqt(), vaqp(), vacall(vaqa, (1, VaS(), VaS()))) == (false, false, false, :TypeError)
member!(VaX, VaS)

@testset "a negative at a Vararg tail, at Type{S} and at a declared supertype's parameter" begin
    @test (vaqv(), vaqt(), vaqp()) == (true, true, true)    # compiled before the membership
    @test vacall(vaqa, (1, VaS(), VaS())) === true
end

# inside an invariant parameter two types are equal in every world or in none: a variable bound inside
# the parameter compares its bounds with no entry, while at the top a membership counts
@set EqX
struct EqS end
struct EqPh{T} end
const EqA = let T = TypeVar(:T, EqX, Any); UnionAll(T, EqPh{T}) end              # EqPh{T} where T >: EqX
const EqB = let T = TypeVar(:T, Union{EqX, EqS}, Any); UnionAll(T, EqPh{T}) end  # where T >: Union{EqX, EqS}
eq_answers() = (EqPh{EqA} <: EqPh{EqB}, EqPh{EqB} <: EqPh{EqA}, EqPh{EqA} == EqPh{EqB},
                typeintersect(EqPh{EqA}, EqPh{EqB}), EqPh{EqA}() isa EqPh{EqB})
const eq_before = eq_answers()
@test !(EqA == EqB)
member!(EqX, EqS)

@testset "a variable bound inside an invariant parameter compares its bounds with no entry" begin
    @test eq_before == (false, false, false, Union{}, false)
    @test eq_answers() == eq_before
    @test EqA == EqB                                    # at the top a membership counts
    @test Vector{EqS} <: Vector{<:EqX}                  # a variable bound outside the parameter
    @test Vector{EqPh{EqX}} <: (Vector{EqPh{T}} where T >: EqS)
end
