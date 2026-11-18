# E-318: CSV.write of the session's table, first and again, in a script (no REPL display)
using CSV, DataFrames
D = ENV["DATA"]; tmp = tempname()
df = CSV.read(joinpath(D, "people.csv"), DataFrame)
df.income_k = df.income ./ 1000
for i in 1:3
    t = @elapsed CSV.write(tmp, df)
    println("write ", i, " ", round(t, digits = 3), " s")
end
println(size(df), " threads ", Threads.nthreads())
