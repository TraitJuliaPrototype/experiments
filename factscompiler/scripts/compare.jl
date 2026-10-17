# Compare two runs of bench.jl: geometric mean of time ratios (on/off) per group and overall, and
# every benchmark slower by more than 20%.   julia scripts/compare.jl <off-label> <on-label>
using Serialization, Printf
off, on = (joinpath(@__DIR__, "..", "results", l) for l in ARGS[1:2])
allr = Float64[]; slow = Tuple{Float64,String,Float64,Float64}[]
for f in sort(readdir(off))
    isfile(joinpath(on, f)) || continue
    a = deserialize(joinpath(off, f)); b = deserialize(joinpath(on, f))
    rs = Float64[]
    for (k, (t0, m0, n0)) in a
        haskey(b, k) || continue
        t1, m1, n1 = b[k]
        r = t1 / t0; push!(rs, r); push!(allr, r)
        r > 1.2 && push!(slow, (r, splitext(f)[1] * "/" * k, t0, t1))
    end
    isempty(rs) && continue
    @printf("%-12s %5d  geomean %.3f  min %.2f  max %.2f\n", splitext(f)[1], length(rs), exp(sum(log, rs) / length(rs)), minimum(rs), maximum(rs))
end
@printf("%-12s %5d  geomean %.3f\n", "ALL", length(allr), exp(sum(log, allr) / length(allr)))
println("\nslower by more than 20% (ratio, benchmark, off ns, on ns):")
for (r, k, t0, t1) in sort(slow; rev = true)[1:min(end, 60)]
    @printf("  %6.2f  %-80s %10.0f %10.0f\n", r, k[1:min(end, 80)], t0, t1)
end
