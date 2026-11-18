# E-364: the library and two members, in trait form.
module Geometry
using TraitWorld
@trait_module
export Shape, area, perimeter, label, ratio, report
@trait Shape begin
    area(s::Shape)::Float64
    perimeter(s::Shape)::Float64
    label(s::Shape)::String = "shape"
end
ratio(s::Shape) = area(s) / perimeter(s)
report(s::Shape) = string(label(s), ": area ", round(area(s); digits = 3), ", ratio ", round(ratio(s); digits = 3))
end
using .Geometry, TraitWorld
struct Circle
    r::Float64
end
@implement Shape Circle begin
    area(c) = pi * c.r^2
    perimeter(c) = 2pi * c.r
    label(c) = "circle"
end
struct Rect
    w::Float64
    h::Float64
end
@implement Shape Rect begin
    area(r) = r.w * r.h
    perimeter(r) = 2 * (r.w + r.h)
end
