# Step 0 of the speed plan: BaseBenchmarks on the built compiler, with no compiler copy. The mode is
# the system image's: the normal image (plain) or the facts image (`all`, -J usr/lib/julia/facts/sys.so,
# with a depot of its own). Run with --pkgimages=no, so the benchmark kernels compile in this session.
#     julia [-J facts/sys.so] --pkgimages=no --project=step0/benv step0/scripts/bench.jl <label> <seconds> group...
using BenchmarkTools, BaseBenchmarks, Serialization
label, secs = ARGS[1], parse(Float64, ARGS[2])
println("image: ", unsafe_string(Base.JLOptions().image_file), "  label: ", label)
out = joinpath(@__DIR__, "..", "..", "results", label); mkpath(out)
for g in ARGS[3:end]
    BaseBenchmarks.load!(g)
    grp = BaseBenchmarks.SUITE[g]
    n = length(BenchmarkTools.leaves(grp))
    t = time()
    tune!(grp; seconds = secs / 4)
    r = run(grp; seconds = secs, verbose = false)
    m = Dict(join(string.(k), "/") => (time(minimum(v)), memory(minimum(v)), allocs(minimum(v))) for (k, v) in BenchmarkTools.leaves(r))
    serialize(joinpath(out, g * ".jls"), m)
    println(rpad(g, 12), n, " benchmarks, ", round(time() - t, digits = 1), " s")
    flush(stdout)
end
