# W-142: Base as the build rebinds it: `invokelatest` (the build binds the name to a direct call).
include("geometry_trait.jl")
double(x::Int) = 2x
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, Base.invokelatest(double, length(args))::Int)
    return 0
end
