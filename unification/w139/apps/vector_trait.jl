# E-364 (b): a loop over a Vector{Shape}: each item is known only by its trait.
include("geometry_trait.jl")
function (@main)(args::Vector{String})::Cint
    shapes = Shape[Circle(1.0), Rect(2.0, 3.0), Circle(0.5)]
    for s in shapes
        println(Core.stdout, report(s))
    end
    return 0
end
