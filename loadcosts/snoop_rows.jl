# E-146: what the whole-call compile of rows.jl's "second model function" and "first gradient"
# infers, without loads and with the big loads after the first solve. @snoop_inference around each
# row; SnoopCompile loads only after the measurements.
#     julia snoop_rows.jl none|after
using SnoopCompileCore
const MODE = ARGS[1]
using TraitDifferentialEquations, TraitWorld, ForwardDiff
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
rossler!(du, u, p, t) = (du[1] = -u[2] - u[3]; du[2] = u[1] + p[1] * u[2]; du[3] = p[2] + u[3] * (u[1] - p[3]); nothing)
const U0, P0 = [1.0, 0.0, 0.0], [10.0, 28.0, 8 / 3]
solve(ODEProblem(lorenz!, U0, (0.0, 1.0), P0), Tsit5())
MODE == "after" && @eval using CSV, DataFrames, CairoMakie
t2 = @snoop_inference solve(ODEProblem(rossler!, U0, (0.0, 1.0), [0.2, 0.2, 5.7]), Tsit5())
loss1(p) = sum(solve(ODEProblem(lorenz!, U0, (0.0, 1.0), p), Tsit5()).u[end])
t5 = @snoop_inference gradient(loss1, copy(P0))
using SnoopCompile
for (name, t) in (("second model function", t2), ("first gradient", t5))
    fl = SnoopCompile.flatten(t)
    tot = sum(inclusive.(t.children); init = 0.0)
    println("== $name ($MODE): inference total ", round(1000tot; digits = 1), " ms, ", length(fl), " frames")
    for f in sort(fl; by = exclusive, rev = true)[1:min(25, length(fl))]
        println("  ", round(1000exclusive(f); digits = 1), " ms  ", Core.Compiler.get_ci_mi(f.ci), "  owner=", f.ci.owner)
    end
end
