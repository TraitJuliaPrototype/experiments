# One process of the go/no-go measurement (plan §3): BaseBenchmarks groups under the compiler copy,
# with the facts mode as JULIA_FACTS_COMPILER sets it. Run with --pkgimages=no, so that package code
# (the benchmark kernels) is compiled in this session by the active compiler.
#     julia --pkgimages=no --project=benv scripts/bench.jl <label> <seconds> group...
using Compiler
Compiler.activate!(; reflection = true, codegen = true)
using BenchmarkTools, BaseBenchmarks, Serialization
label, secs = ARGS[1], parse(Float64, ARGS[2])
println("facts mode: ", Compiler.FACTS_MODE[], "  label: ", label)
out = joinpath(@__DIR__, "..", "results", label); mkpath(out)
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
