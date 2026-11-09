# E-323: a display's run time at an IOBuffer, the REPL's way (text/plain, limited), after its first call:
# the session's people.csv and a 10^4-row frame; 20 calls each.
#   cd forks-unified && unset JULIA_DEPOT_PATH && DATA=data julia --project=env_forks show_time.jl
using CSV, DataFrames, Statistics, Dates
D = get(ENV, "DATA", "data")
df = CSV.read(joinpath(D, "people.csv"), DataFrame)
big = DataFrame(a = 1:10^4, b = (1:10^4) ./ 7, c = string.(1:10^4))
buf = IOBuffer()
io = IOContext(buf, :limit => true, :displaysize => (40, 120))
for (name, x) in (("people", df), ("big", big))
    t0 = time_ns(); show(io, MIME"text/plain"(), x); t1 = (time_ns() - t0) / 1e6
    n = position(buf)
    ts = Float64[]
    for _ in 1:20
        truncate(buf, 0); seekstart(buf)
        t = time_ns(); show(io, MIME"text/plain"(), x); push!(ts, (time_ns() - t) / 1e6)
    end
    println(rpad(name, 8), "first ", round(t1, digits = 1), " ms; then min ", round(minimum(ts), digits = 3),
            " median ", round(median(ts), digits = 3), " ms; ", n, " bytes")
end
