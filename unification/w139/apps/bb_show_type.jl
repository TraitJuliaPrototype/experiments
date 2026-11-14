# W-142: Base as the build replaces it: a type printed (`show(::IO, ::Type)`, replaced by the build script).
include("geometry_trait.jl")
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, "a ", string(typeof(args)), " of ", length(args))
    return 0
end
