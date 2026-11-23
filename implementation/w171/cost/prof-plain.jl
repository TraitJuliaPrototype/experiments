# W-171, fourth part (E-545): where plain code's session spends its time, by function. Upstream CSV and DataFrames,
# compiled plainly (w19's envs/up), the work of w19's motiv/f-plain.jl. One process: the load under the sampling
# profiler (C frames included), then the first work under it. For each phase, per function the samples whose stack
# holds it (inclusive, counted once per sample) and those where it is the leaf; the format of w19's motiv/g-profile.jl,
# so that w19's tools/g-profcmp.py compares two builds.
#     julia --project=<w19>/envs/up prof-plain.jl <csv> <out-prefix>   -> <out-prefix>-load.tsv, <out-prefix>-work.tsv
using Profile
const csv, pre = ARGS[1], ARGS[2]
Profile.init(n = 10^7, delay = 0.0001)
fname(fr) = string(fr.func, " @ ", basename(string(fr.file)))
function dump(out, t)
    data = Profile.fetch(include_meta = false)
    lidict = Profile.getdict(data)
    incl = Dict{String,Int}(); self = Dict{String,Int}()
    nsamp = 0; seen = Set{String}(); leaf = true
    for ip in data
        if ip == 0
            if !leaf
                nsamp += 1; empty!(seen)
            end
            leaf = true
            continue
        end
        for fr in lidict[ip]
            n = fname(fr)
            if leaf
                self[n] = get(self, n, 0) + 1; leaf = false
            end
            if !(n in seen)
                push!(seen, n); incl[n] = get(incl, n, 0) + 1
            end
        end
    end
    open(out, "w") do io
        println(io, "# ms\t", round(t; digits = 1), "\tsamples\t", nsamp)
        for (n, c) in sort!(collect(incl); by = last, rev = true)
            c < 3 && break
            println(io, c, "\t", get(self, n, 0), "\t", n)
        end
    end
    return nsamp
end
GC.gc()
t0 = time_ns()
@profile @eval using CSV, DataFrames
t = (time_ns() - t0) / 1e6
n = dump(pre * "-load.tsv", t)
println("load ", round(t; digits = 1), " ms, samples ", n)
Profile.clear()
w = @eval () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                 g = combine(groupby(df, names(df)[end]), c => sum); string(hash(repr((d, first(s, 3), g))); base = 16))
t0 = time_ns()
@profile Base.invokelatest(w)
t = (time_ns() - t0) / 1e6
n = dump(pre * "-work.tsv", t)
println("first work ", round(t; digits = 1), " ms, samples ", n)
