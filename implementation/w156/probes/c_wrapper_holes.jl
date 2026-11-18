# W-156 third part (compiler C-114): the closed check's holes at the wrapper of a value known only by its trait.
# Run from TraitWorld/: julia --project=. <this file> [patch.jl]
using TraitWorld, Test
length(ARGS) >= 1 && include(ARGS[1])
@trait Shape2 begin
    area2(s::Shape2)::Float64
end
struct Circ; r::Float64; end
struct Sq; a::Float64; end
area2(c::Circ) = 3.0 * c.r^2
area2(s::Sq) = s.a^2
@implement Shape2 Circ
@implement Shape2 Sq
scaled2(s::Shape2, k::Float64) = k * area2(s)
wrapsum(xs::Vector{Shape2}) = (s = 0.0; for x in xs; s += scaled2(compiled_for(x), 2.0)::Float64; end; s)
r = verify_main(wrapsum, (Vector{Shape2},))
println("holes: ", length(r.holes))
foreach(h -> println("  ", h), r.holes)
println("targets:"); foreach(t -> println("  ", t), r.targets)
println("result: ", wrapsum(Shape2[Circ(1.0), Sq(2.0)]))
# a call that does not know its argument's member, at a method that is not at the trait: the instance at the set
@noinline plainpair(x) = (x, area2(x))
plainuse(xs::Vector{Shape2}) = plainpair(xs[1])[2]
@noinline typedpair(x::T) where {T} = (x, area2(x))
typeduse(xs::Vector{Shape2}) = typedpair(xs[1])[2]
for f in (plainuse, typeduse)
    r = verify_main(f, (Vector{Shape2},))
    println(f, ": holes ", length(r.holes), "; targets at the set or a member: ",
            filter(t -> t.parameters[1] in (typeof(plainpair), typeof(typedpair)), r.targets))
end
