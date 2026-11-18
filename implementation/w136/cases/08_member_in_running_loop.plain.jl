include(joinpath(@__DIR__, "..", "lib_plain.jl")); using .Geometry
println("PHASE definition")
function session()
    shapes = Shape[]
    Core.eval(Main, quote
        struct Circle <: Shape
            r::Float64
        end
        Geometry.area(c::Circle) = pi * c.r^2
        Geometry.perimeter(c::Circle) = 2pi * c.r
    end)
    c = Base.invokelatest(getglobal(Main, :Circle), 1.0)
    println("PHASE call")
    push!(shapes, c)
    println(Base.invokelatest(report, shapes[1]))
end
session()
println("PHASE end")
