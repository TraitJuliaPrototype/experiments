
# a builtin's check of a store by an empty intersection about a set proves no throw: the stores compiled
# before a membership run once the value is a member
@set StX
struct StS end
mutable struct StMB; v::StX; StMB() = new(); end
ststf(x) = (m = StMB(); setfield!(m, :v, x); true)
stmrs(x) = (Core.memoryrefset!(Core.memoryrefnew(Memory{StX}(undef, 1)), x, :not_atomic, true); true)
sttry(f, x) = try f(x) catch e; e isa TypeError ? :TypeError : rethrow() end
@test (sttry(ststf, StS()), sttry(stmrs, StS())) == (:TypeError, :TypeError)
@test Base.return_types(ststf, (StS,)) == [Bool]
member!(StX, StS)

@testset "a builtin's check by an empty intersection about a set is no proof" begin
    @test ststf(StS())
    @test stmrs(StS())
end
