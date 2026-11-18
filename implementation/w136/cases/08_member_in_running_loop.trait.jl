include(joinpath(@__DIR__, "..", "lib_trait.jl")); using .Geometry, TraitWorld
println("PHASE definition")
function session()
    shapes = Shape[]
    Core.eval(Main, quote
        struct Circle
            r::Float64
        end
        @implement Shape Circle begin
            area(c) = pi * c.r^2
            perimeter(c) = 2pi * c.r
        end
    end)
    c = Base.invokelatest(getglobal(Main, :Circle), 1.0)
    println("PHASE call")
    push!(shapes, c)
    println(Base.invokelatest(report, shapes[1]))
end
session()
println("PHASE end")
