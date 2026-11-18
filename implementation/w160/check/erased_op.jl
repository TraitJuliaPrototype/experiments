# W-160 (d), E-443: what an operation costs on a value known only by its trait, now (GT-7; the review's P7 (a), a
# witness in the box). A trait with six members; a box held of the first member declared (a branch of the split)
# and of the sixth (past the first four: the table, through a pointer made at the member's first use); beside
# them the operation at a known type and Julia's dynamic call of a function held as `Any`. And the first call
# at the sixth member in a fresh process (the pointer's making). 10^7 calls, the minimum of 5, ns a call.
using TraitWorld
t0 = time_ns()
module T
using TraitWorld
@trait_module first_seen = false
@trait Shape begin
    area(s::Shape)::Float64
end
for (i, n) in enumerate((:S1, :S2, :S3, :S4, :S5, :S6))
    @eval struct $n; a::Float64; end
    @eval area(s::$n) = $(Float64(i)) * s.a
    @eval @implement Shape $n
end
end
const N = 10^7
const SINK = Ref(0.0)
ns(h, args...) = (h(args..., 10); round(minimum(@elapsed(SINK[] += h(args..., N)) for _ in 1:5) / N * 1e9; digits = 2))
lop(d::Dynamic{T.Shape}, n) = (s = 0.0; for _ in 1:n; s += T.area(d); end; s)
lknown(c::T.S1, n) = (s = 0.0; for _ in 1:n; s += T.area(c); end; s)
const ANY = Ref{Any}(T.S6(1.0))
lany(n) = (s = 0.0; for _ in 1:n; s += T.area(ANY[])::Float64; end; s)
d6 = Dynamic{T.Shape}(T.S6(1.0))
first6 = @elapsed T.area(d6)                # the first call at the sixth member: its pointer made
println("first call at the sixth member (s)       ", round(first6; digits = 4))
println("the operation at a known type            ", ns(lknown, T.S1(1.0)))
println("on a box, the first member (a branch)    ", ns(lop, Dynamic{T.Shape}(T.S1(1.0))))
println("on a box, the sixth member (the table)   ", ns(lop, d6))
println("a dynamic call of a value held as Any    ", ns(lany))
