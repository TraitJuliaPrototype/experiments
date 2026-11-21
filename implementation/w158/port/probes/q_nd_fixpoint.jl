# W-158 (open issue 246): NetworkDynamics' `find_fixpoint`, which calls TraitNonlinearSolve's `solve` (the nonlinear
# front end) with a `SteadyStateProblem` of the network at a fixed time; the test subset has no such call. A small network
# with a fixpoint (diffusion with a source and a decay at each vertex), solved with the default polyalgorithm and with
# NewtonRaphson, with a keyword passed on. Prints the solution's digest and the return type the caller infers.
# Project ../../../w161/nd/env_test_head.
using NetworkDynamics, TraitDifferentialEquations, Graphs
const TNS = TraitDifferentialEquations.TraitNonlinearSolve
vm = VertexModel(; f = (dv, v, esum, p, t) -> (dv[1] = esum[1] - v[1] + p[1]; nothing), dim = 1, pdim = 1, g = 1, indim = 1)
em = EdgeModel(; g = AntiSymmetric((e, vs, vd, p, t) -> (e .= vs .- vd; nothing)), outdim = 1, indim = 1)
nw = Network(path_graph(4), [vm for _ in 1:4], [em for _ in 1:3]; dealias = true)
s0 = NWState(nw); s0.v[:, 1] .= 0.0; s0.p.v[:, 1] .= [1.0, 2.0, 3.0, 4.0]
for (name, kw) in (("default", (;)), ("NewtonRaphson", (; alg = NewtonRaphson())), ("abstol", (; abstol = 1e-12)))
    s = find_fixpoint(nw, uflat(s0), pflat(s0); kw...)
    println(name, ": ", join(round.(uflat(s); sigdigits = 12), ","))
end
prob = SteadyStateProblem(NetworkDynamics.NetworkFixedT(nw, 0.0), uflat(s0), pflat(s0))
println("solve's inferred result: ", Base.return_types(TNS.solve, (typeof(prob), typeof(NewtonRaphson())))[1])
println("solve(prob, NewtonRaphson()): ", TNS.solve(prob, NewtonRaphson()).retcode)
