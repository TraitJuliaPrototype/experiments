# The policy on general code no image holds under it: a DataFrames/CSV workload, natively or
# compiled under the policy (TraitWorld._facts_call), fresh session each.
mode = ARGS[1]
using DataFrames, CSV, Statistics, TraitWorld
function work(n)
    df = DataFrame(a = rand(1:10, n), b = rand(n), c = string.(rand('a':'e', n)))
    g = combine(groupby(df, :a), :b => mean => :mb, :c => (x -> length(unique(x))) => :nc)
    sort!(g, :a)
    io = IOBuffer(); CSV.write(io, g); length(String(take!(io)))
end
kernel(v) = (s = 0.0; for x in v; s += sin(x)^2; end; s)
call(f, x) = mode == "facts" ? TraitWorld._facts_call(f, x) : f(x)
t1 = @elapsed call(work, 1000)
t2 = minimum(@elapsed(call(work, 10^5)) for _ in 1:5)
v = rand(10^6)
t3 = @elapsed call(kernel, v)
t4 = minimum(@elapsed(call(kernel, v)) for _ in 1:5)
println(rpad(mode, 7), "DataFrames workload: first call ", round(t1, digits = 2), " s, steady ", round(t2 * 1000, digits = 1),
        " ms; numeric kernel: first ", round(t3 * 1000, digits = 1), " ms, steady ", round(t4 * 1000, digits = 2), " ms")
