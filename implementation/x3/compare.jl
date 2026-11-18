# E-269: the quick subset's ratios against a control: geometric mean of time ratios, the largest ones.
#     julia compare.jl <results dir of the control> <results dir to compare>
using Serialization, Printf
mergekeys(d) = Dict(g * "/" * k => v for f in readdir(d) if endswith(f, ".jls") for g in (f[1:end-4],) for (k, v) in deserialize(joinpath(d, f)))
a, b = mergekeys(ARGS[1]), mergekeys(ARGS[2])
ks = sort(collect(intersect(keys(a), keys(b))))
r = [b[k][1] / a[k][1] for k in ks]
@printf("%d benchmarks: geomean %.3f, median %.3f\n", length(r), exp(sum(log.(r)) / length(r)), sort(r)[cld(length(r), 2)])
for i in sortperm(r; rev = true)[1:5]
    @printf("  %6.3f  %s\n", r[i], ks[i])
end
for i in sortperm(r)[1:3]
    @printf("  %6.3f  %s\n", r[i], ks[i])
end
