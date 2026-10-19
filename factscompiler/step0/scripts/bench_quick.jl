# The quick subset (step0/quick.txt), each benchmark tuned and run briefly; results as bench.jl's.
#     julia [-J facts/sys.so] --pkgimages=no --project=step0/benv step0/scripts/bench_quick.jl <label> [seconds]
using BenchmarkTools, BaseBenchmarks, Serialization
label = ARGS[1]; secs = length(ARGS) > 1 ? parse(Float64, ARGS[2]) : 0.05
sel = Set(readlines(joinpath(@__DIR__, "..", "quick.txt")))
groups = unique(first.(split.(collect(sel), "/")))
println("image: ", basename(dirname(unsafe_string(Base.JLOptions().image_file))), "  label: ", label, "  ", length(sel), " benchmarks")
out = joinpath(@__DIR__, "..", "..", "results", label); mkpath(out)
t = time()
for g in sort(groups)
    BaseBenchmarks.load!(g)
    m = Dict{String,Tuple{Float64,Int,Int}}()
    for (k, b) in BenchmarkTools.leaves(BaseBenchmarks.SUITE[g])
        key = join(string.(k), "/")
        g * "/" * key in sel || continue
        tune!(b; seconds = secs / 4)
        r = minimum(run(b; seconds = secs))
        m[key] = (time(r), memory(r), allocs(r))
    end
    serialize(joinpath(out, g * ".jls"), m)
end
println("done in ", round(time() - t; digits = 1), " s")
