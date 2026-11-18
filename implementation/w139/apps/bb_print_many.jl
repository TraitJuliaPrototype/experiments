# W-142: Base as the build sets it: `print` with seven arguments (the build raises the function's
# `max_args`, a setting of the type and no method).
include("geometry_trait.jl")
function (@main)(args::Vector{String})::Cint
    n = length(args)
    println(Core.stdout, "a ", n, " b ", n + 1, " c ", 2.5, " d")
    return 0
end
