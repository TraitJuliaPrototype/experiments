# W-166 (open issue 241): TraitNonlinearSolve loaded by a trimmed build (with TraitDifferentialEquations; its precompile workload runs while the build loads it).
using TraitDifferentialEquations
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, "loaded")
    return 0
end
