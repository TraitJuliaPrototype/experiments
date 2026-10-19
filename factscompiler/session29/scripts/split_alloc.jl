using TraitWorld
@trait_module module Shapes
using TraitWorld
export Shp, sarea, stotal
@trait Shp{R} begin
    sarea(r::R)::Float64
end
struct Sq; a::Float64; end
struct Ci; r::Float64; end
@implement Shp{Sq} begin sarea(s) = s.a^2 end
@implement Shp{Ci} begin sarea(c) = 3.0 * c.r^2 end
function stotal(v::Vector{Dynamic{Shp}})
    s = 0.0
    for d in v
        s += sarea(d)
    end
    return s
end
end
v = repeat(Dynamic{Shapes.Shp}[Dynamic{Shapes.Shp}(Shapes.Sq(2.0)), Dynamic{Shapes.Shp}(Shapes.Ci(1.0))], 1000)
Shapes.stotal(v); Shapes.stotal(v)
a = @allocated Shapes.stotal(v)
t = minimum(@elapsed(Shapes.stotal(v)) for _ in 1:200)
println("stotal over 2000: ", Shapes.stotal(v), "  allocated ", a, " bytes, ", round(t / 2000 * 1e9; digits = 2), " ns per element")
