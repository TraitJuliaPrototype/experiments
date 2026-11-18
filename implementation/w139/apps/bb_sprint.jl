# W-142: Base as the build replaces it: `sprint` with a function and a context.
include("geometry_trait.jl")
function (@main)(args::Vector{String})::Cint
    s = sprint(print, length(args) + 1; context = :compact => true)
    println(Core.stdout, s)
    return 0
end
