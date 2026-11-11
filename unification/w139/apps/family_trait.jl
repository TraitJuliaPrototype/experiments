# E-364 (d): a family of members, `Scaled{T} where T`: the build lists the instantiations it has made.
include("geometry_trait.jl")
struct Scaled{T}
    inner::T
    k::Float64
end
@implement Shape Scaled{T} where {T} begin
    area(s) = s.k^2 * area(s.inner)
    perimeter(s) = s.k * perimeter(s.inner)
    label(s) = "scaled"
end
function (@main)(args::Vector{String})::Cint
    shapes = Shape[Circle(1.0), Scaled(Rect(2.0, 3.0), 2.0), Scaled(Circle(1.0), 0.5), Scaled(Scaled(Rect(1.0, 1.0), 2.0), 3.0)]
    for s in shapes
        println(Core.stdout, report(s))
    end
    return 0
end
