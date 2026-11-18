# E-362: the library of the cases, in trait form. A user's mistake is made against this contract.
module Geometry
using TraitWorld
@trait_module
export Shape, area, perimeter, label, ratio, title, report, Named, tag, Scalable, scale

@trait Shape begin
    area(s::Shape)::Float64
    perimeter(s::Shape)::Float64
    label(s::Shape)::String = "shape"
end
ratio(s::Shape) = area(s) / perimeter(s)
title(s::Shape) = uppercasefirst(label(s)) * " of area " * string(round(area(s); digits = 3))
report(s::Shape) = string(title(s), ", ratio ", round(ratio(s); digits = 3))

@trait Named begin
    @const name::String
end
tag(n::Named) = "<" * n.name * ">"
tag(s::Shape) = "[" * label(s) * "]"

@trait Scalable begin
    scale(s::Scalable, k::Float64)::Self
end
end
