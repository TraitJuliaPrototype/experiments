# W-142: a hole inside plain code the program calls: Base's `repeat(::Char, ::Int)` (TraitTables' table
# program, E-364).
include("geometry_trait.jl")
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, repeat('-', length(args) + 3))
    return 0
end
