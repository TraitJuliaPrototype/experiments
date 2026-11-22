# W-170 (E-538): the dynamic calls of NetworkDynamics' Tsit5 solve of step d (the head's dispatch profiler, whole
# process: run with JULIA_DISPATCH_PROFILE=1; the solve repeated NREP times after the workload's steps a-d, so the
# solve's sites lead the counts); run from ndport/ as nd_steady.jl is.
const ND = joinpath(@__DIR__, "..", "..", "..", "ndport", "scripts")
using Graphs, NetworkDynamics, TraitDifferentialEquations, SymbolicIndexingInterface
include(joinpath(ND, "workload_steps.jl"))
Base.invokelatest() do
    a = NDW.step_a(:swing); nw = NDW.step_b(a); c = NDW.step_c(nw)
    r = NDW.step_d(nw, c.s); r = NDW.step_d(nw, c.s)
    prob = r.prob
    alg = get(ENV, "ND_ALG", "tsit5") == "tsit5" ? Tsit5() : NDW.STIFF()
    for _ in 1:parse(Int, get(ENV, "NREP", "100"))
        solve(remake(prob; p = copy(prob.p)), alg; NDW.SOLVE_KW..., NDW.SAVE_KW...)
    end
end
