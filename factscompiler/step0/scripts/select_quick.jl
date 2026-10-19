# The quick subset of BaseBenchmarks, from a full pair of runs (session 28: full0 plain, full1 facts):
# every benchmark slower by more than 2x, the 10 most faster, and per group 4 neutral controls
# (ratio 0.9-1.1, at least 1 us), drawn with a fixed seed. Writes step0/quick.txt, one "group/key" a line.
#     julia step0/scripts/select_quick.jl full0 full1
using Serialization, Random
off, on = (joinpath(@__DIR__, "..", "..", "results", l) for l in ARGS[1:2])
rows = Tuple{String,Float64,Float64}[]
for f in readdir(off)
    isfile(joinpath(on, f)) || continue
    a = deserialize(joinpath(off, f)); b = deserialize(joinpath(on, f)); g = splitext(f)[1]
    for (k, (t0, _, _)) in a
        haskey(b, k) && push!(rows, (g * "/" * k, b[k][1] / t0, t0))
    end
end
tails = [r[1] for r in rows if r[2] > 2]
faster = [r[1] for r in sort(rows; by = r -> r[2])[1:10]]
rng = Xoshiro(29)
controls = String[]
for g in unique(first.(split.(first.(rows), "/")))
    c = [r[1] for r in rows if startswith(r[1], g * "/") && 0.9 <= r[2] <= 1.1 && r[3] >= 1000]
    append!(controls, shuffle(rng, c)[1:min(end, 4)])
end
sel = sort(unique(vcat(tails, faster, controls)))
open(joinpath(@__DIR__, "..", "quick.txt"), "w") do io; foreach(s -> println(io, s), sel); end
println(length(tails), " tails, ", length(faster), " faster, ", length(controls), " controls: ", length(sel), " benchmarks")
