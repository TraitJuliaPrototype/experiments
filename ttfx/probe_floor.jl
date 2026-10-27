# E-176: the load of a candidate plotting core's dependencies, without Makie: julia --project=env_up probe_floor.jl
using TOML
man = TOML.parsefile(joinpath(dirname(Base.active_project()), "Manifest.toml"))["deps"]
id(name) = Base.PkgId(Base.UUID(man[name][1]["uuid"]), name)
core = ["ColorTypes", "Colors", "FixedPointNumbers", "Observables", "ComputePipeline", "GeometryBasics", "StaticArrays",
        "GridLayoutBase", "FreeType", "FreeTypeAbstraction", "PlotUtils", "Format", "Cairo", "PNGFiles"]
n0 = length(Base.loaded_modules)
t = @elapsed for p in core; Base.require(id(p)); end
println("candidate core: ", round(t; digits = 2), " s, packages +", length(Base.loaded_modules) - n0)
t2 = @elapsed Base.require(id("MathTeXEngine"))
println("+ MathTeXEngine (Makie's default text): ", round(t2; digits = 2), " s, packages total +", length(Base.loaded_modules) - n0)
