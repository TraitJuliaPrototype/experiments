# E-364 (e): a cast to `Compiled` on a value known only by its trait: `report(compiled_for(s))`. A
# session dispatches on the value's type when the call runs; a closed build branches over the members.
include("geometry_trait.jl")
function (@main)(args::Vector{String})::Cint
    shapes = Shape[Circle(1.0), Rect(2.0, 3.0), Circle(0.5)]
    for s in shapes
        println(Core.stdout, report(compiled_for(s)))
    end
    return 0
end
