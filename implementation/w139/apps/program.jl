# E-364: a program for `make_executable` and `make_library`: functions of `Main` written in a file.
include("geometry_trait.jl")
const SHAPES = Shape[Circle(1.0), Rect(2.0, 3.0), Circle(0.5)]
function shapes_main(args::Vector{String})
    for s in SHAPES
        println(Core.stdout, report(s))
    end
    return 0
end
"The summed area of the first `n` shapes, for C."
function total_area(n::Cint)::Cdouble
    t = 0.0
    for i in 1:min(Int(n), length(SHAPES))
        t += area(SHAPES[i])
    end
    return t
end
untyped_main(args::Vector{String}) = (x = Any[1, "a"][length(args) + 1]; println(Core.stdout, string(x + 1)); 0)
