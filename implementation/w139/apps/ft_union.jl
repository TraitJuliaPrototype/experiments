# W-142: a call at a union of two concrete types. A build splits it.
include("geometry_trait.jl")
pick(i::Int) = i > 0 ? Circle(1.0) : 2.5
describe(c::Circle) = "circle"
describe(x::Float64) = "number"
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, describe(pick(length(args))))
    return 0
end
