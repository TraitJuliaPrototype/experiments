# W-170 (E-538), open issue 261: what a call of a box at two signatures guarantees (traits §9, compiler §7.4), before
# and after the fix: the arguments asserted to a signature (MethodError outside both), the result to that signature's
# `S` (TypeError), at either signature; and the dynamic calls one call of the box makes (the dispatch profiler, run
# with JULIA_DISPATCH_PROFILE=1).
#     JULIA_DISPATCH_PROFILE=1 julia --project=<env> probe261.jl
using TraitWorld, Test
f(x::Float64) = 2x
f(x::Int) = x + 1
g(x::Float64) = 2x
g(x::Int) = "not an Int"                     # a result outside the second signature's S
const FB = Dynamic{All{Callable{Tuple{Float64},Float64},Callable{Tuple{Int},Int}}}
callat(b, x) = b(x)
@testset "a box at two signatures (open issue 261)" begin
    b = FB(f)
    @test callat(b, 1.5) === 3.0 && callat(b, 2) === 3
    @test_throws MethodError callat(b, "x")
    @test_throws MethodError callat(b, 1.0f0)
    bg = FB(g)
    @test callat(bg, 1.5) === 3.0
    e = try callat(bg, 2); nothing catch err; err end
    @test e isa TypeError && e.expected === Int
    @test_throws MethodError FB(uppercase)         # the box is made only at a function with methods at both
    # a box of one signature, unchanged
    b1 = Dynamic{Callable{Tuple{Float64},Float64}}(g)
    @test callat(b1, 1.5) === 3.0 && (@test_throws MethodError callat(b1, 2)) isa Any
end
@noinline many(b, x, n) = (s = 0.0; for _ in 1:n; s += b(x); end; s)
b = FB(f); many(b, 1.5, 10)
t = time_ns(); many(b, 1.5, 10^6); println("R a box of two signatures, f(1.5): ", (time_ns() - t) / 10^6, " ns a call")
