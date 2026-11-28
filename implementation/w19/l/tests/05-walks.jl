
# a membership's walk replays the types a pattern bounded by the set puts under a set (`BpP{Z} where Z <: BpX`
# is in `BpX`): a call at `BpP{BpS}` compiled before `BpS` joins `BpX` follows, and taken back follows again
@set BpX
struct BpS end
struct BpP{T} end
member!(BpX, let Z = TypeVar(:Z, BpX); UnionAll(Z, BpP{Z}) end)
bph(::BpX) = :set
bph(::Any) = :any
bpcall(c::BpP{BpS}) = bph(c)
@test bpcall(BpP{BpS}()) === :any
member!(BpX, BpS)
const bpw = world()
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), BpS, BpX, @__MODULE__)

@testset "a membership's walk replays a pattern bounded by the set" begin
    @test Base.invoke_in_world(bpw, bpcall, BpP{BpS}()) === :set
    @test bpcall(BpP{BpS}()) === :any
end

# the walks reach what lies past their depth (a set nine tuples deep), and a member below a lower bound's top
@set DpX
struct DpS end
struct DpP{T} end
dpnest(T, n) = n == 0 ? T : Tuple{dpnest(T, n - 1)}
dpnestv(x, n) = n == 0 ? x : (dpnestv(x, n - 1),)
const DpDX = dpnest(DpX, 9)
const DpDS = dpnest(DpS, 9)
dpg(::Any) = :any
dpg(::DpDX) = :deep
dph(::Any) = :any
dph(::DpP{T}) where T >: Tuple{DpS} = :lb
dpcg(x::DpDS) = dpg(x)
dpch(x::DpP{Tuple{DpX}}) = dph(x)
const dpv = dpnestv(DpS(), 9)
@test (dpcg(dpv), dpch(DpP{Tuple{DpX}}())) == (:any, :any)
member!(DpX, DpS)

@testset "the walks reach past their depth and below a lower bound's top" begin
    @test dpcg(dpv) === :deep
    @test dpch(DpP{Tuple{DpX}}()) === :lb
end
