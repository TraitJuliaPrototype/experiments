# W-166: plain code that calls LAPACK while a trimmed build loads it (Colors' constants, a workload's solve).
using LinearAlgebra
const M = inv([2.0 1.0; 1.0 3.0])
println(Core.stdout, "at load: ", M[1, 1])
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, "M ", M[1, 1])
    return 0
end
