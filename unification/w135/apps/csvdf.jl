# E-361 (5): upstream CSV with DataFrames: a file read, described and sorted.
using CSV, DataFrames
function (@main)(args::Vector{String})::Cint
    df = CSV.read(args[1], DataFrame)
    println(Core.stdout, "rows ", nrow(df), " columns ", ncol(df))
    d = sort(df, 1)
    println(Core.stdout, "first ", d[1, 1])
    return 0
end
