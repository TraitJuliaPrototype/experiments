# E-269 (X3): the quick BaseBenchmarks subset (factscompiler/step0/quick.txt, 148 benchmarks) with the
# methods of install.jl in place. As factscompiler/step0/scripts/bench_quick.jl, results in x3/results/<label>/.
#     X3_MEMBERS=<k> <tree>/julia --startup-file=no --pkgimages=no \
#         --project=experiments/factscompiler/step0/benv bench_quick.jl <label>
include(joinpath(@__DIR__, "install.jl"))
using BenchmarkTools, BaseBenchmarks, Serialization
label = ARGS[1]; secs = 0.05
sel = Set(readlines(joinpath(@__DIR__, "..", "..", "factscompiler", "step0", "quick.txt")))
groups = unique(first.(split.(collect(sel), "/")))
println("label: ", label, "  members: ", K, "  ", length(sel), " benchmarks")
out = joinpath(@__DIR__, "results", label); mkpath(out)
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
