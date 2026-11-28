
# what a membership would replay, for a library's check before it: the patterns bounded by the set at the
# member, as the walk replays them
@set RsX
struct RsS end
struct RsP{T} end
member!(RsX, let Z = TypeVar(:Z, RsX); UnionAll(Z, RsP{Z}) end)
rsh(::RsX) = :set
rsh(::Any) = :any

@testset "what a membership would replay names the patterns bounded by the set" begin
    rs = ccall(:jl_membership_replay_sigs, Any, (Any, Any), RsS, RsX)::Vector{Any}
    sigs = [rs[i+1] for i in 1:2:length(rs)-1 if rs[i] === which(rsh, Tuple{RsX})]
    @test any(s -> s isa Type && Tuple{typeof(rsh), RsP{RsS}} <: s, sigs)
end
