# W-158, fourth part (C-152's rest): a default's method at a trait, at a box kept at a place typed by the trait: the
# lowered code of the default's method, and the build's check round by round (`../probes/rounds.jl`) with the code of
# the default's instances. Before (TraitWorld unified 82959cf): the receiver read through `_fwd`, the split at it keeps a
# box branch; after (w158f): `getfield(d, :object)`, no box branch. Run from the library's project (either tree).
using TraitWorld
@trait Shape13 begin
    area13(s::Shape13)::Float64 = 1.0
end
struct Sq13; a::Float64; end
area13(s::Sq13) = s.a^2
struct Pt13; end
@implement Shape13 Sq13
@implement Shape13 Pt13
boxes13(n::Int) = (v = Shape13[Dynamic{Shape13}(Sq13(Float64(n))), Pt13(), Dynamic{Shape13}(Pt13())];
                   s = 0.0; for x in v; s += area13(x); end; s)
println("library: ", pathof(TraitWorld))
println("the default's lowered code:")
println(Base.uncompressed_ast(which(area13, Tuple{Shape13})))
include(joinpath(@__DIR__, "..", "probes", "rounds.jl"))
check_rounds(boxes13, (Int,); show = "", showcode = r"area13|boxes13")
println("result: ", boxes13(2))
