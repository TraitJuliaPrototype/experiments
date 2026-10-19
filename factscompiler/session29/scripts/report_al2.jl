include("/tmp/claude-1000/demos/tally.jl")
const csv = "/home/hellmann/Repos/julia-trait-bound/experiments/interfaces/App/data/sample.csv"
for p in split(get(ENV, "PK", "OffsetArrays StatsBase Unitful")); Core.eval(Main, Meta.parse("using $p")); end
invs = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
@eval using TraitReport
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
# verify_methods entries: (codeinst, "verify_methods", cause) triples
nfacts = 0; causes = Dict{String,Int}()
for i in eachindex(invs)
    x = invs[i]
    if x isa String && x == "verify_methods" && i > 1
        ci = invs[i-1]; cause = i < length(invs) ? invs[i+1] : nothing
        if ci isa Core.CodeInstance && ci.owner === :facts
            global nfacts += 1
            k = first(string(cause), 200); causes[k] = get(causes, k, 0) + 1
        end
    end
end
println("facts CodeInstances failing image validation: ", nfacts, " (log entries ", length(invs), ")")
for (k, v) in first(sort(collect(causes); by = last, rev = true), 15); println("  ×", v, "  ", k); end
t0 = tally()
@time TraitReport.report(csv, joinpath(mktempdir(), "r.png"); io = IOBuffer())
t1 = tally(); println("  new CIs: ", sort(collect(diff(t0, t1)); by = string))
