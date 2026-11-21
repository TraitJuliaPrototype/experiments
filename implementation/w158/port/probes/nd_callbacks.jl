# W-158, the other ports: NetworkDynamics' network callbacks through `get_callbacks` and `ODEProblem(nw, ...; add_nw_cb)`
# on a small diffusion network (the test subset has no callback file): a continuous component callback,
# a network callback of TDE's own, and none. Prints the callbacks' type and the events' times. Project w161/nd/env_test_head.
using NetworkDynamics, TraitDifferentialEquations, Graphs
const ODE = TraitDifferentialEquations
function net()
    g = path_graph(4)
    vm = VertexModel(; f = (dv, v, esum, p, t) -> (dv .= esum; nothing), dim = 1, g = 1, indim = 1)
    em = EdgeModel(; g = AntiSymmetric((e, vs, vd, p, t) -> (e .= vs .- vd; nothing)), outdim = 1, indim = 1)
    Network(g, [vm for _ in 1:4], [em for _ in 1:3]; dealias = true)
end
nw = net()
println("no callbacks: ", get_callbacks(nw))
ct = Float64[]; dt = Float64[]
ccond = ComponentCondition([:s], []) do u, p, t; u[:s] - 1.0; end
caff = ComponentAffect([], []) do u, p, ctx; push!(ct, ctx.t); nothing; end
set_callback!(nw[VIndex(1)], ContinuousComponentCallback(ccond, caff))
# (a DiscreteComponentCallback is left out: the discrete batch's affect returns the user's value, a Bool here, and TDE
# takes `Nothing`: a defect of the port's `to_callbacks(::DiscreteCallbackWrapper)`, the same before and after)
cbs = get_callbacks(nw)
println("callbacks: ", typeof(cbs), " ", length(cbs))
s0 = NWState(nw); s0.v[:, :s] .= [3.0, 0.0, 0.0, 0.0]
nt = Float64[]
extra = ODE.DiscreteCallback((u, t, i) -> t > 4.0 && isempty(nt), i -> (push!(nt, i.t); nothing))
for kw in ((;), (; add_nw_cb = extra), (; add_nw_cb = (extra,)), (; add_nw_cb = [extra]))
    empty!(ct); empty!(dt); empty!(nt)
    prob = ODEProblem(nw, uflat(s0), (0.0, 6.0), copy(pflat(s0)); kw...)
    sol = solve(prob, Tsit5())
    println(keys(kw), ": ", typeof(prob.callbacks).name.name, " events cont ", round.(ct; digits = 4), " disc ", round.(dt; digits = 4),
            " net ", round.(nt; digits = 4), " end ", round(sol.u[end][1]; digits = 8), " steps ", length(sol.t))
end
