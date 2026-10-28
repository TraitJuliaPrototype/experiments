# An A/B probe (W-85's worked example): a plain caller calling a bounded function with a declared result,
# with values of a type it does not know (an untyped call, through the table of declared implementations).
# TraitWorld 38a3abf put the declared result on the entry, so the plain caller's inference sees it.
#     experiments/tools/ab/ab.sh TraitWorld 38a3abf^ - experiments/tools/ab/examples/entry_result.jl
include(joinpath(ENV["AB_TOOLS"], "ABProbe.jl")); using .ABProbe
t = @elapsed using TraitWorld
abreport("using_TraitWorld"; ms = t * 1e3)
@trait_module module P
using TraitWorld
export Shape, sarea
@trait Shape begin
    area(s::Shape)::Float64
end
struct Sq; a::Float64; end
struct Circ; r::Float64; end
@implement Shape Sq begin area(s) = s.a^2 end
@implement Shape Circ begin area(s) = 3.14159 * s.r^2 end
sarea(s::Shape)::Float64 = 2 * area(s)        # a bounded function with a declared result
end
using .P
# a plain caller that does not know its values' types
function plainsum(xs::Vector{Any})
    s = 0.0
    for x in xs
        s += sarea(x)
    end
    return s
end
xs = Any[isodd(i) ? P.Sq(1.0 * i) : P.Circ(0.5 * i) for i in 1:1000]
abmeasure("untyped_calls", () -> plainsum(xs); per = length(xs))
abreport("inferred"; result_is_Float64 = Int(Base.return_types(plainsum, (Vector{Any},))[1] === Float64))
