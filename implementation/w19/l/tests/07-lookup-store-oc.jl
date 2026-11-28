
# a lookup at a set that dropped a method records the pairs whose absence it relied on: a call compiled at
# the set before the membership selects the member's own method after it
@set LdX
struct LdS end
struct LdT end
member!(LdX, LdT)
ldg(::LdX) = :X
ldg(::LdS) = :S
Base.@nospecializeinfer ldq(@nospecialize(x::LdX)) = ldg(x)
@test ldq(LdT()) === :X
member!(LdX, LdS)

@testset "a lookup at a set records the pairs whose absence dropped a method" begin
    @test ldq(Base.inferencebarrier(LdS())) === :S
end

# a store's test about a set that inference did not prove is not consistent: a caller does not evaluate
# it at compile time and keep its `TypeError`
@set SpX
struct SpS end
struct SpP{T} end
mutable struct SpMP; v::SpP{<:SpX}; SpMP() = new(); end
spstp(x) = (m = SpMP(); setfield!(m, :v, x); true)
sprtp(x) = spstp(x)
sptry(f, x) = try f(x) catch e; e isa TypeError ? :TypeError : rethrow() end
@test sptry(sprtp, SpP{SpS}()) === :TypeError
member!(SpX, SpS)

@testset "a store's test about a set that inference did not prove is not consistent" begin
    @test sprtp(SpP{SpS}())
end

# an opaque closure's call at an argument that could join the closure's set is left to the closure's own
# test: the caller compiled before the membership calls it once the membership holds
@set OcX
struct OcS end
ocf() = (oc = Base.Experimental.@opaque (x::OcX) -> :called; oc(OcS()))
octry(g) = try g() catch e; Symbol(nameof(typeof(e))) end
const oca = octry(ocf)
member!(OcX, OcS)
const ocb = octry(ocf)
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), OcS, OcX, @__MODULE__)

@testset "an opaque closure's call decides its test about a set only with a record" begin
    @test (oca, ocb, octry(ocf)) == (:TypeError, :called, :TypeError)
end
