using TraitWorld
@trait_module module RD
using TraitWorld
export Sh, area, label, describe
@trait Sh begin
    area(s::Sh)::Float64
    label(s::Sh)::String = "shape"
end
describe(s::Sh) = label(s) * " of area " * string(area(s))
end
struct Ci; r::Float64; end
RD.area(c::Ci) = 3.0 * c.r^2
@implement RD.Sh Ci
println("conformance method: ", TraitWorld._has_conformance_method(RD.Sh, Ci), " is_trait: ", TraitWorld.is_trait(RD.Sh))
println(macroexpand(Main, :(@implement RD.Sh Ci begin label(c) = "circle" end)) |> string |> s -> first(s, 300))
