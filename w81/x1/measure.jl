# E-210 (X1): one right-hand side seen at the duals, against a second kept function at the duals.
# A fresh process: Rodas5's first solve timed whole, then a Jacobian call (Dynamic and compiled).
t0 = time()
using TraitDifferentialEquations, TraitWorld
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
U0, P0 = [1.0, 0.0, 0.0], [10.0, 28.0, 8/3]
tload = time() - t0
t1 = @elapsed (s = solve(ODEProblem(lorenz!, U0, (0.0, 1.0), P0), Rodas5()))
t2 = @elapsed solve(ODEProblem(lorenz!, U0, (0.0, 1.0), P0), Rodas5(chunk_size = 0))
function jbench(prob)
    J = zeros(3, 3); u = [1.0, 2.0, 3.0]
    jacobian!(prob, J, u, 0.0)
    best = Inf
    for _ in 1:5
        t = @elapsed for _ in 1:10^5; jacobian!(prob, J, u, 0.0); end
        best = min(best, t)
    end
    return best * 1e4
end
pd = ODEProblem(lorenz!, U0, (0.0, 1.0), P0); pc = ODEProblem(compiled_for(lorenz!), U0, (0.0, 1.0), P0)
println("X load ", round(tload; digits = 2), " s; first Rodas5 solve ", round(t1 * 1000; digits = 1), " ms; chunk at init ", round(t2 * 1000; digits = 1), " ms")
println("X jacobian! Dynamic ", round(jbench(pd); digits = 1), " ns; compiled ", round(jbench(pc); digits = 1), " ns")
println("X u[end] ", s.u[end])
