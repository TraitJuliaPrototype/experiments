# E-157 check 3: allocations per step of a Tsit5 solve, a 40-state chain (ChainModel{PathGraph}),
# ~1,000 steps (dtmax = 0.01 over 10 time units; saveat = [tf], so saving adds nothing per step).
# Per step = (a solve over 20 time units − one over 10) / (the steps in between): the setup cancels.
# Dynamic and compiled_for; Vector p and named-tuple p (bits, and holding a vector). For
# information: Rodas5 with the problem's Jacobian (chunk 8) and with the chunk picked at init.
include(joinpath(@__DIR__, "common.jl"))
using ChainModels
header("check 3", "allocations per step: Tsit5, 40 states, ~1,000 steps")

function measured(prob, alg, tf)
    g0 = Base.gc_num(); t0 = time_ns()
    s = solve(prob, alg; dtmax = 0.01, saveat = [tf])
    t1 = time_ns(); d = Base.GC_Diff(Base.gc_num(), g0)
    return s, (t1 - t0), d.allocd, Base.gc_alloc_count(d)
end
const U0 = collect(range(0.0, 1.0; length = 40))
const M = ChainModel(PathGraph(40))
cases = [("p::Vector{Float64}", [1.0, 0.1]), ("p::NamedTuple (bits)", (k = 1.0, d = 0.1)),
         ("p::NamedTuple (holds a Vector)", (k = 1.0, d = 0.1, w = fill(1.0, 40)))]
println(rpad("case", 34), rpad("alg", 24), rpad("mode", 14), lpad("steps", 7), lpad("f calls/step", 13),
        lpad("bytes/step", 12), lpad("allocs/step", 12), lpad("ns/step", 10), lpad("allocs (1,000 steps)", 22))
for (label, p) in cases, (alglabel, alg) in (("Tsit5", Tsit5()), ("Rodas5 (chunk 8)", Rodas5()), ("Rodas5 (chunk at init)", Rodas5(chunk_size = 0)))
    for (mode, f) in (("Dynamic", M), ("compiled_for", compiled_for(M)))
        pr(tf) = ODEProblem(f, U0, (0.0, tf), p)
        measured(pr(10.0), alg, 10.0); measured(pr(20.0), alg, 20.0)        # warm-up
        best = nothing
        for _ in 1:3
            s1, t1, b1, a1 = measured(pr(10.0), alg, 10.0)
            s2, t2, b2, a2 = measured(pr(20.0), alg, 20.0)
            st = (s2.naccept + s2.nreject) - (s1.naccept + s1.nreject)
            r = (steps = s1.naccept + s1.nreject, fps = (s2.nf - s1.nf) / st, bps = (b2 - b1) / st, aps = (a2 - a1) / st,
                 nsps = (t2 - t1) / st, a1 = a1)
            best = best === nothing || r.nsps < best.nsps ? r : best
        end
        @printf("%-34s%-24s%-14s%7d%13.1f%12.1f%12.2f%10.0f%22d\n", label, alglabel, mode, best.steps, best.fps, best.bps, best.aps, best.nsps, best.a1)
    end
end
footer()
