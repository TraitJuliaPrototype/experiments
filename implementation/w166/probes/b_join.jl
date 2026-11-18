# W-166b: what the join of the wrapper's branches is, and what a closed check says of a call that takes it.
using TraitWorld
const CC = Base.Compiler
@trait Shape5 begin
    area5(s::Shape5)::Float64
end
struct S1; a::Float64; end
struct S2; a::Float64; end
struct S3; a::Float64; end
struct S4; a::Float64; end
struct S5; a::Float64; end
area5(s::S1) = 1.0 * s.a
area5(s::S2) = 2.0 * s.a
area5(s::S3) = 3.0 * s.a
area5(s::S4) = 4.0 * s.a
area5(s::S5) = 5.0 * s.a
for T in (S1, S2, S3, S4, S5)
    @eval @implement Shape5 $T
end
scaled5(s::Shape5, k::Float64) = k * area5(s)
wrapsum5(xs::Vector{Shape5}) = (s = 0.0; for x in xs; s += scaled5(compiled_for(x), 2.0)::Float64; end; s)

U3 = Union{Compiled{S1}, Compiled{S2}, Compiled{S3}}
@show CC.tmerge(U3, Compiled{S4})
@show CC.tmerge(Union{Compiled{S1}, Compiled{S2}}, Compiled{S3})
@show CC.tmerge(CC.fallback_lattice, Union{Compiled{S1}, Compiled{S2}, Compiled{S3}}, Compiled{S4})
r = verify_main(wrapsum5, (Vector{Shape5},))
@show r.holes
ft = fully_typed(wrapsum5, (Vector{Shape5},))
@show isfullytyped(ft)
display(ft)
@show wrapsum5(Shape5[S1(1.0), S2(1.0), S3(1.0), S4(1.0), S5(1.0)])
