# E-169: which key makes stock SciML compile its first solve in the session: the user's function type
# (class (e)), the keywords (class (f)), or both. One variant per process: julia probe_keys.jl <variant>
#   nokw: solve(prob, Tsit5()), p = Float64[] (the shape of OrdinaryDiffEq's workload, with Main's function)
#   kw:   the same with saveat, reltol, abstol (the workload's keywords)
#   kw2:  after nokw, the kw call (what the keywords add once the function's code exists)
#   fn2:  after kw, a second Main function with the same keywords (what a new function adds)
using OrdinaryDiffEqTsit5
function lorenz!(du, u, p, t); du[1] = 10.0 * (u[2] - u[1]); du[2] = u[1] * (28.0 - u[3]) - u[2]; du[3] = u[1] * u[2] - 8 / 3 * u[3]; nothing; end
function other!(du, u, p, t); du[1] = -u[1]; du[2] = -u[2]; du[3] = -u[3]; nothing; end
P(f) = ODEProblem(f, [1.0, 0.0, 0.0], (0.0, 1.0), Float64[])
kw = (saveat = collect(0.0:0.01:1.0), reltol = 1e-6, abstol = 1e-8)
v = ARGS[1]
t(f) = (t0 = time(); f(); round(time() - t0; digits = 3))
if v == "nokw"; println("nokw ", t(() -> solve(P(lorenz!), Tsit5())))
elseif v == "kw"; println("kw ", t(() -> solve(P(lorenz!), Tsit5(); kw...)))
elseif v == "kw2"; println("nokw ", t(() -> solve(P(lorenz!), Tsit5())), " then kw ", t(() -> solve(P(lorenz!), Tsit5(); kw...)))
elseif v == "fn2"; println("kw ", t(() -> solve(P(lorenz!), Tsit5(); kw...)), " then a new function, kw ", t(() -> solve(P(other!), Tsit5(); kw...)))
end
