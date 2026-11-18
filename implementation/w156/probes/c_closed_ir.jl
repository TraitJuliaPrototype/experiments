# W-156 third part: the IR a closed build's rules give the wrapper's calls (compiler §7.6). From TraitWorld/:
# julia --project=. <this file> [patch.jl]
using TraitWorld
const CC = Base.Compiler
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
interp = CC.NativeInterpreter(Base.get_world_counter(); closed = CC.ClosedCheck())
for (f, tt) in ((wrapsum, (Vector{Shape2},)), (compiled_for, (Shape2,)))
    println("== ", f, tt)
    display(only(Base.code_typed(f, tt; interp)))
end
