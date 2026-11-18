# W-142: a call on a value typed Any: a run-time site in both.
include("geometry_trait.jl")
const BOX = Any[Circle(1.0)]
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, report(BOX[1]))
    return 0
end
