# E-248 (W-96): upstream_ref.jl's problems on TDE (the project given), the same lines, for comparison.
#     julia --project=<TDE> tde_probe.jl
using TraitDifferentialEquations, TraitWorld
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
const P0 = [10.0, 28.0, 8 / 3]
const U0 = [1.0, 0.0, 0.0]
const TS = [0.137, 0.5, 0.731]
const TOL = get(ENV, "TOL", "default")
const KW = TOL == "default" ? (;) : (; abstol = parse(Float64, TOL), reltol = parse(Float64, TOL))
println("TOL ", TOL)
show17(x) = repr(x)
let
prob = ODEProblem(lorenz!, U0, (0.0, 1.0), P0)
s = solve(prob, Tsit5(); KW...)
println("A naccept ", s.naccept, " nreject ", s.nreject, " nsaved ", length(s.t))
println("A dense ", show17([s(τ) for τ in TS]))
sa = solve(prob, Tsit5(); KW..., saveat = TS)
println("A saveat ", show17(sa.u))
st = solve(prob, Tsit5(); abstol = 1e-12, reltol = 1e-12)
println("A tight ", show17([st(τ) for τ in TS]))
println("A naccept-tight ", (hasproperty(st, :stats) ? st.stats.naccept : st.naccept))
println("A err dense ", maximum(maximum(abs.(s(τ) .- st(τ))) for τ in TS), " at steps ", maximum(maximum(abs.(s.u[k] .- st(s.t[k]))) for k in eachindex(s.t)))
end
for (name, alg) in (("Tsit5", Tsit5()), ("Rodas5", Rodas5()))
    te = Float64[]
    cb = ContinuousCallback((u, t, i) -> u[3] - 25.0, i -> (push!(te, i.t); i.u[2] *= 0.9; nothing))
    pb = ODEProblem(lorenz!, U0, (0.0, 3.0), P0)
    sb = solve(pb, alg; KW..., callback = cb)
    println("B $name events ", show17(te))
    println("B $name naccept ", sb.naccept, " nsaved ", length(sb.t), " end ", show17(sb.u[end]))
    k = findfirst(==(te[1]), sb.t)
    println("B $name first event at ", k, ": ", show17(sb.t[k:k+1]), " ", show17(sb.u[k]), " ", show17(sb.u[k+1]))
    empty!(te)
    sv = solve(pb, alg; KW..., callback = cb, saveat = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0])
    println("B $name saveat t ", show17(sv.t))
    println("B $name saveat u ", show17(sv.u[[findfirst(==(τ), sv.t) for τ in [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]]]))
    empty!(te)
    local st = solve(pb, alg; callback = cb, abstol = 1e-12, reltol = 1e-12)
    println("B $name tight events ", show17(te))
end
