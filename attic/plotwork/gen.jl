# Writes the workload's data: n rows of a time series in five groups. Plain Julia, no packages,
# deterministic (a linear congruential generator), so both modes read the same file.
n = parse(Int, ARGS[1]); path = ARGS[2]
s = UInt64(42)
r() = (global s = s * 6364136223846793005 + 1442695040888963407; Float64(s >> 11) / 2.0^53)
groups = ("alpha", "beta", "gamma", "delta", "epsilon")
open(path, "w") do io
    println(io, "t,group,x,y,n,flag")
    for i in 1:n
        g = groups[1 + (i % 5)]
        x = i / n * 10
        y = sin(x + (i % 5)) + 0.3 * (r() - 0.5)
        println(io, round(i * 0.01; digits = 2), ',', g, ',', round(x; digits = 5), ',',
                round(y; digits = 5), ',', 1 + floor(Int, 100 * r()), ',', r() < 0.1 ? "true" : "false")
    end
end
