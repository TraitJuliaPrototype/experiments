# E-362: the library of the cases, in plain Julia: an abstract type and documented generic functions.
module Geometry
export Shape, area, perimeter, label, ratio, title, report, tag, scale

"""
    Shape

A subtype implements `area(s)::Float64` and `perimeter(s)::Float64`, and may implement `label(s)::String`.
"""
abstract type Shape end
function area end
function perimeter end
label(s::Shape) = "shape"
ratio(s::Shape) = area(s) / perimeter(s)
title(s::Shape) = uppercasefirst(label(s)) * " of area " * string(round(area(s); digits = 3))
report(s::Shape) = string(title(s), ", ratio ", round(ratio(s); digits = 3))

"`tag(x)`: for a shape its label; for anything with a field `name::String`, the name."
tag(s::Shape) = "[" * label(s) * "]"
tag(n) = "<" * n.name * ">"

"`scale(s, k::Float64)`: a shape of `s`'s type, `k` times as large. A scalable shape implements it."
function scale end
end
