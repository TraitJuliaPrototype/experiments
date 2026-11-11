# E-364 (a): every call at a concrete member.
include("geometry_trait.jl")
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, report(Circle(1.0)))
    println(Core.stdout, report(Rect(2.0, 3.0)))
    return 0
end
