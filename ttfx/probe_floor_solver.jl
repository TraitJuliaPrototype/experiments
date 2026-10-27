# E-176: the solver's floor: Tsit5's tree plus ForwardDiff (a Rosenbrock method's Jacobian with a dense LU), against
# OrdinaryDiffEqRosenbrock's.   julia --project=env_up probe_floor_solver.jl
using TOML
man = TOML.parsefile(joinpath(dirname(Base.active_project()), "Manifest.toml"))["deps"]
id(name) = Base.PkgId(Base.UUID(man[name][1]["uuid"]), name)
n0 = length(Base.loaded_modules)
t = @elapsed for p in ("OrdinaryDiffEqTsit5", "ForwardDiff", "DiffEqBase"); Base.require(id(p)); end
println("Tsit5 + ForwardDiff + DiffEqBase: ", round(t; digits = 2), " s, packages +", length(Base.loaded_modules) - n0)
t2 = @elapsed Base.require(id("OrdinaryDiffEqRosenbrock"))
println("+ OrdinaryDiffEqRosenbrock: ", round(t2; digits = 2), " s more, packages total +", length(Base.loaded_modules) - n0)
