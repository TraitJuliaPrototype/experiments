# E-198 part B: a pirate defined before a package image whose trait code it breaks. In strict mode TraitWorld
# reports it at the load (a PirateAtLoadError naming the pirate and the code); off, the load is silent. Either
# way the image's code is compiled again and computes the pirate's result.
#     JULIA_TW_STRICT=1|0 julia --project=<env with TraitDifferentialEquations> pirate_before.jl wins|nowhere
case = ARGS[1]
using TraitWorld                                            # the hooks and the validation log, before the pirate
case == "wins" && @eval Base.abs2(x::Float64) = 1.0001 * x * x
case == "nowhere" && @eval Base.abs2(x::Rational{Int8}) = x * x  # a pirate at a signature no trait code calls
using TraitDifferentialEquations
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
sol = solve(ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 1.0), [10.0, 28.0, 8 / 3]), Tsit5())
println("R case ", case, " strict ", TraitWorld.STRICT[], " reported ", length(TraitWorld._LOAD_PIRATES),
        " ", join(unique(string(e.method.module, ".", e.method.name, " in ", Core.Compiler.get_ci_mi(e.code).def.name) for e in TraitWorld._LOAD_PIRATES), "; "),
        "  steps ", length(sol.t), "  u(end) ", repr(sol.u[end][1]))
