# W-170 (E-538): NetworkDynamics' step d, its digest (the workload's own `digest_d`: retcodes, the trips and their
# times, ω₂ at the saved times, every saved state's bits), on the port; run from ndport/ as nd_steady.jl is:
#     cd ndport; NDW_STACK=ports NDW_API=ports julia --project=<nd env> nd_digest.jl
const ND = joinpath(@__DIR__, "..", "..", "..", "ndport", "scripts")
using Graphs, NetworkDynamics, TraitDifferentialEquations, SymbolicIndexingInterface
include(joinpath(ND, "workload_steps.jl"))
Base.invokelatest() do
    a = NDW.step_a(:swing); nw = NDW.step_b(a); c = NDW.step_c(nw)
    r = NDW.step_d(nw, c.s)
    NDW.digest_d(r)
end
