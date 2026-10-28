# E-200 (W-72, the facts-first review §2.5): the share of `rests_on_facts` in a session's compilation, by sampling.
# The workload runs under the profiler; samples whose stack holds `rests_on_facts`, `facts_plain_return_type`,
# and inference at all are counted.
#     julia --project=<env> profile_rests.jl <workload script> <outdir>
using Profile
Profile.init(n = 10^8, delay = 0.001)
const _SCRIPT, _OUT = ARGS[1], ARGS[2]
empty!(ARGS); push!(ARGS, _OUT)
@profile include(joinpath(dirname(@__DIR__), "..", "ttfx", _SCRIPT))
data = Profile.fetch()
lidict = Profile.getdict(data)
names = Dict(k => [String(f.func) for f in v] for (k, v) in lidict)
nsamp = 0; nrest = 0; nfprt = 0; ninf = 0
stack = String[]
for x in data
    if x == 0
        if !isempty(stack)
            global nsamp += 1
            any(==("rests_on_facts"), stack) && (global nrest += 1)
            any(==("facts_plain_return_type"), stack) && (global nfprt += 1)
            any(s -> s == "typeinf" || s == "typeinf_ext_toplevel", stack) && (global ninf += 1)
        end
        empty!(stack)
    else
        append!(stack, get(names, x, String[]))
    end
end
println("P samples ", nsamp, "; in inference ", ninf, "; in facts_plain_return_type ", nfprt, "; in rests_on_facts ", nrest,
        " (", round(100nrest / max(ninf, 1); digits = 2), "% of inference)")
