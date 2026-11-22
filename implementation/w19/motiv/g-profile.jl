# W-19, third part: where `using CSV, DataFrames` spends its time (GT-34). Upstream CSV and DataFrames, compiled
# plainly (envs/up). One process: the load under the sampling profiler (C frames included), then per function
# the samples whose stack holds it (inclusive, counted once per sample) and the samples where it is the leaf.
#     julia --project=envs/up g-profile.jl <out.tsv>
# The first line of the output: the load's time, the samples, the session's own counters.
using Profile
const out = ARGS[1]
Profile.init(n = 10^7, delay = 0.0001)
GC.gc()
t0 = time_ns()
@profile @eval using CSV, DataFrames
t = (time_ns() - t0) / 1e6
data = Profile.fetch(include_meta = false)
lidict = Profile.getdict(data)
fname(fr) = string(fr.func, " @ ", basename(string(fr.file)))
incl = Dict{String,Int}(); self = Dict{String,Int}()
nsamp = 0
seen = Set{String}()
leaf = true
for ip in data
    global nsamp, leaf
    if ip == 0
        if !leaf   # the end of a sample
            nsamp += 1
            empty!(seen)
        end
        leaf = true
        continue
    end
    for fr in lidict[ip]
        n = fname(fr)
        if leaf
            self[n] = get(self, n, 0) + 1
            leaf = false
        end
        if !(n in seen)
            push!(seen, n)
            incl[n] = get(incl, n, 0) + 1
        end
    end
end
open(out, "w") do io
    println(io, "# load_ms\t", round(t; digits = 1), "\tsamples\t", nsamp)
    for (n, c) in sort!(collect(incl); by = last, rev = true)
        c < 3 && break
        println(io, c, "\t", get(self, n, 0), "\t", n)
    end
end
println("load ", round(t; digits = 1), " ms, samples ", nsamp)
