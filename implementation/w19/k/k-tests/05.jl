# a positive about a Vararg tail and a declared supertype's parameter comes through the entry: code
# compiled while the membership holds ends when it is taken back
@set VbX
struct VbS end
abstract type VbAP{T} end
struct VbP{T} <: VbAP{T} end
member!(VbX, VbS)
vbpv() = Tuple{Int, VbS, VbS} <: Tuple{Int, Vararg{VbX}}
vbpp() = VbP{VbS} <: VbAP{<:VbX}
@test (vbpv(), vbpp()) == (true, true)
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), VbS, VbX, @__MODULE__)

@testset "a positive at a Vararg tail and at a declared supertype's parameter, taken back" begin
    @test (vbpv(), vbpp()) == (false, false)
end

# taken back, a membership ends the callers of the member's instance that has no code (`applicable`,
# `hasmethod` folded through it), as a method's deletion does
@set RmX
struct RmS end
rmh(::RmX) = :h
rmqa(x) = applicable(rmh, x)
rmqh() = hasmethod(rmh, Tuple{RmS})
member!(RmX, RmS)
@test rmqa(RmS()) && rmqh()
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), RmS, RmX, @__MODULE__)

@testset "a membership taken back ends the callers of an instance with no code" begin
    @test !applicable(Base.inferencebarrier(rmh), Base.inferencebarrier(RmS()))
    @test rmqa(RmS()) === false
    @test rmqh() === false
end

# a method whose variable's lower bound names the member (`h(::Ph{T}) where T >: S`) is selected at a
# type that names the set once the member joins it: the walk replays it, declared or taken back
@set LrX
@set LrY
struct LrS end
struct LrPh{T} end
const LrB = let T = TypeVar(:T, LrS, Any); UnionAll(T, LrPh{T}) end    # LrPh{T} where T >: LrS
lrh(::LrB) = :hB
lrg(::Any) = :Any
lrg(::LrB) = :B
lrhm() = hasmethod(lrh, Tuple{LrPh{LrX}})
lrd(x) = lrg(x)
lrap(x) = applicable(lrh, x)
const lrv = LrPh{LrX}()
lrdyn(x) = lrg(Base.inferencebarrier(x))
lrd2(x) = lrg(x)
lrhm2() = hasmethod(lrh, Tuple{LrPh{LrX}})
@test lrhm() === false && lrd(lrv) === :Any && lrap(lrv) === false && lrdyn(lrv) === :Any
const lrw = UInt[world()]
member!(LrX, LrS)
push!(lrw, world())

@testset "a membership replays the methods whose lower bound the member meets" begin
    @test lrhm() === true
    @test lrd(lrv) === :B
    @test lrap(lrv) === true
    @test lrdyn(lrv) === :B
end

ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), LrS, LrX, @__MODULE__)
push!(lrw, world())

@testset "the methods whose lower bound the member meets, taken back" begin
    @test (lrhm(), lrd(lrv), lrap(lrv), lrdyn(lrv)) == (false, :Any, false, :Any)
    @test lrd2(lrv) === :Any && lrhm2() === false
    @test [Base.invoke_in_world(w, lrd2, lrv) for w in lrw] == [:Any, :B, :Any]
    @test [Base.invoke_in_world(w, lrhm2) for w in lrw] == [false, true, false]
end

member!(LrY, LrS)
@test lrhm() === false && lrd(lrv) === :Any
member!(LrX, LrY)                                     # a path of two: LrS in LrY, LrY in LrX
@test lrhm() === true && lrd(lrv) === :B && lrdyn(lrv) === :B
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), LrS, LrY, @__MODULE__)

@testset "a lower bound met through a path of two memberships, its first taken back" begin
    @test (lrhm(), lrd(lrv), lrdyn(lrv)) == (false, :Any, :Any)
end

# a membership at every instance of a set reaches a method at one instance
@set EvX A
struct EvS end
evg(::Any) = :Any
evg(::EvX{Int}) = :B
evq(x) = evg(x)
evdyn(x) = evg(Base.inferencebarrier(x))
@test evq(EvS()) === :Any && evdyn(EvS()) === :Any
member!(EvX, EvS)                                     # every instance

@testset "a membership at every instance reaches a method at one instance" begin
    @test EvS() isa EvX{Int}
    @test evq(EvS()) === :B
    @test evdyn(EvS()) === :B
end
