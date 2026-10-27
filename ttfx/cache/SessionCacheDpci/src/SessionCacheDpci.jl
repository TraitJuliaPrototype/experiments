# E-172: an emulated cache across sessions: the statements a perturbed session compiled (trace.jl), those that
# do not name Main, compiled into this package's image.
module SessionCacheDpci
using PlainODE, PlainPlots
for (id, m) in Base.loaded_modules
    n = Symbol(id.name)
    isdefined(@__MODULE__, n) || Core.eval(@__MODULE__, :(const $n = $m))
end
include_dependency(joinpath(@__DIR__, "trace.jl"))   # the statements are this package's source too
const COUNTS = let ok = 0, failed = 0, skipped = 0
    for line in eachline(joinpath(@__DIR__, "trace.jl"))
        startswith(line, "precompile") || continue
        if occursin("Main.", line); skipped += 1; continue; end
        r = try Core.eval(@__MODULE__, Meta.parse(line)) catch; false end
        r === true ? (ok += 1) : (failed += 1)
    end
    (ok = ok, failed = failed, skipped = skipped)
end
end
