# E-356: the repeated work by step, in microseconds (the least and the median of 2,000), as a control of plain
# code's steady state.    julia --project=env_up|env_lib steady.jl <csv> none|first
const csv = ARGS[1]
ARGS[2] == "first" && @eval using TraitWorld
using CSV, DataFrames, Statistics
function steps(csv, n)
    df = CSV.read(csv, DataFrame); c = names(df)[1]; k = names(df)[end]
    t = zeros(n, 4)
    for i in 1:n
        t[i, 1] = @elapsed CSV.read(csv, DataFrame)
        t[i, 2] = @elapsed describe(df)
        t[i, 3] = @elapsed sort(df, c)
        t[i, 4] = @elapsed combine(groupby(df, k), c => sum)
    end
    return t
end
steps(csv, 20); t = steps(csv, 2000)
us(x) = round(1e6x; digits = 1)
println(join(["$name $(us(minimum(t[:, j]))) / $(us(median(t[:, j])))" for (j, name) in enumerate(("read", "describe", "sort", "groupby"))], " | "),
        " | sum of least ", us(sum(minimum(t; dims = 1))), " us; size ", filesize(csv), " bytes")
