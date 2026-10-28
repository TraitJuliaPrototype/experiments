# W-85: TraitWorld's checks and folds during the forks' import (E-213's member fixes at load), then at the first
# uses of a small session.
#     JULIA_TW_LOADREPORT=1 julia --project=<an env of the forks> experiments/tools/scripts/forks_loadreport.jl
t = @elapsed using CSV, DataFrames, Statistics, Dates
println("using CSV, DataFrames, Statistics, Dates: ", round(t; digits = 3), " s")
using TraitWorld
TraitWorld.loadreport(; top = 5)
TraitWorld.loadreport_switch!(true)                 # again from here: the first uses
t = @elapsed begin
    df = DataFrame(i = rand(1:100, 10^4), f = randn(10^4), s = rand(["a", "b", "c"], 10^4))
    io = IOBuffer(); CSV.write(io, df); df2 = CSV.read(take!(io), DataFrame)
    combine(groupby(df2, :i), :f => sum, :s => length)
end
println("\nfirst uses (a frame, CSV.write, CSV.read, groupby-combine): ", round(t; digits = 3), " s")
TraitWorld.loadreport(; top = 3)
