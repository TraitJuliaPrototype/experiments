# G2 across package loads (facts reference §2.2, deviation F-11): both trait libraries work, then
# stacks load one package at a time, interleaved with work; after each load, every valid
# CodeInstance of the facts owner (`:facts`, the code of trait modules) that was lost is counted,
# by module. Expected: none. Run from the repository root with the demonstrators' environments and
# the big loads' environment, one Julia process:
#   JULIA_LOAD_PATH="TraitMakie/scripts/env:TraitDifferentialEquations/scripts/env:TraitReport/env_loads:@stdlib" \
#     julia-1.13/julia --startup-file=no experiments/facts/g2all.jl interleaved      # or: before, none
order = ARGS[1]                     # "interleaved" or "before" or "none"
const STACK2 = [
    ("OffsetArrays", "6fe1bfb0-de20-5000-8ca7-80f57d26f881"),
    ("StatsBase", "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"),
    ("Unitful", "1986cc42-f94f-5a68-af5c-568840ba703d"),
    ("IntervalArithmetic", "d1acc4aa-44c8-5952-acd4-ba5d80a2a253"),
    ("Distributions", "31c24e10-a181-5473-b8eb-7969acd0382f"),
    ("Interpolations", "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"),
    ("StaticArrays", "90137ffa-7385-5640-81b9-e52037218182"),
]
loadpkg(n, u) = Base.require(Base.PkgId(Base.UUID(u), n))
if order == "before"
    using CSV, DataFrames, CairoMakie
    for (n, u) in STACK2; loadpkg(n, u); end
elseif order == "before_stack1"
    using CSV, DataFrames, CairoMakie
end
using TraitDifferentialEquations, TraitMakie
const TW = TraitMakie.TraitWorld
function allcis()
    out = Core.CodeInstance[]
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                push!(out, ci); isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    out
end
facts_valid() = filter(ci -> ci.owner === :facts && ci.max_world == typemax(UInt), allcis())
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
xs = collect(range(0.0, 10.0; length = 200))
function work()
    t = @elapsed begin
        TraitDifferentialEquations.solve(TraitDifferentialEquations.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 1.0), [10.0, 28.0, 8 / 3]), Tsit5())
        TraitDifferentialEquations.solve(TraitDifferentialEquations.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 1.0), [10.0, 28.0, 8 / 3]), Rodas5())
        TraitDifferentialEquations.solve(TraitDifferentialEquations.ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 1.0), [10.0, 28.0, 8 / 3]), Tsit5();
              callback = DiscreteCallback((u, t, i) -> t > 0.5, i -> (i.u[1] += 1.0; nothing)))
        f = TraitMakie.lines(xs, sin.(xs); color = :blue); TraitMakie.scatter!(f, xs[1:10:end], cos.(xs[1:10:end]); color = :red)
        TraitMakie.save(joinpath(ENV["TMPDIR"], "g2all.png"), f)
    end
    return round(t * 1000, digits = 1)
end
before_set = get(ENV, "NEWCIS", "0") == "1" ? Set(allcis()) : Set{Core.CodeInstance}()
println(order, ": first work ", work(), " ms; again ", work(), " ms; facts-owned valid ", length(facts_valid()))
if get(ENV, "NEWCIS", "0") == "1"
    d = Dict{Any,Int}()
    for ci in allcis()
        ci in before_set && continue
        mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
        k = (mi.def isa Method ? nameof(Base.moduleroot(mi.def.module)) : :top, ci.owner === nothing ? :native : ci.owner)
        d[k] = get(d, k, 0) + 1
    end
    println("  new CodeInstances in the first work: ", sort(collect(d); by = x -> -x[2])[1:min(end, 12)])
end
if order == "interleaved"
    pre = facts_valid()
    steps = Any[(:CSV, () -> @eval(using CSV)), (:DataFrames, () -> @eval(using DataFrames)), (:CairoMakie, () -> @eval(using CairoMakie))]
    for (n, u) in STACK2; push!(steps, (Symbol(n), () -> loadpkg(n, u))); end
    for (name, f) in steps
        tl = @elapsed f()
        lost = filter(ci -> ci.max_world != typemax(UInt), pre)
        mods = Dict{Symbol,Int}()
        for ci in lost
            mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
            k = mi.def isa Method ? nameof(Base.moduleroot(mi.def.module)) : :toplevel
            mods[k] = get(mods, k, 0) + 1
        end
        println("  after ", rpad(name, 18), " load ", lpad(round(tl, digits = 2), 6), " s; facts-owned lost ", length(lost), " of ", length(pre), " ", collect(mods), "; work ", work(), " ms")
    end
end
rossler!(du, u, p, t) = (du[1] = -u[2] - u[3]; du[2] = u[1] + p[1] * u[2]; du[3] = p[2] + u[3] * (u[1] - p[3]); nothing)
t2 = @elapsed TraitDifferentialEquations.solve(TraitDifferentialEquations.ODEProblem(rossler!, [1.0, 0.0, 0.0], (0.0, 1.0), [0.2, 0.2, 5.7]), Tsit5())
t3 = @elapsed TraitDifferentialEquations.solve(TraitDifferentialEquations.ODEProblem(rossler!, [1.0, 0.0, 0.0], (0.0, 1.0), [0.2, 0.2, 5.7]), Rodas5())
println("  a new right-hand side function: Tsit5 ", round(t2 * 1000, digits = 1), " ms, Rodas5 ", round(t3 * 1000, digits = 1), " ms")
# a new key: a user's own problem type (the solver compiles for it, by facts)
struct MyLorenz; u0::Vector{Float64}; tspan::Tuple{Float64,Float64}; p::Vector{Float64}; end
TraitDifferentialEquations.rhs!(m::MyLorenz, du::Vector{Float64}, u::Vector{Float64}, t::Float64) = (lorenz!(du, u, m.p, t); nothing)
@eval TraitDifferentialEquations.TraitWorld.@implement TraitDifferentialEquations.ODEProblemTrait MyLorenz
t4 = @elapsed Base.invokelatest(TraitDifferentialEquations.solve, MyLorenz([1.0, 0.0, 0.0], (0.0, 1.0), [10.0, 28.0, 8 / 3]), Tsit5())
println("  a new problem type (a new key, compiled by facts): ", round(t4 * 1000, digits = 1), " ms")
