# ORDER=after: TDE first, then the loads; counts valid CodeInstances by owner and root module.
function tally()
    d = Dict{Tuple{Any,Symbol},Int}()
    Base.visit(Core.methodtable) do m
        r = nameof(Base.moduleroot(m.module))
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                if ci.max_world == typemax(UInt)
                    k = (ci.owner isa Symbol || ci.owner === nothing ? ci.owner : nameof(typeof(ci.owner)), r in (:Base, :Core, :TraitWorld, :TraitDifferentialEquations, :ForwardDiff) ? r : :other)
                    d[k] = get(d, k, 0) + 1
                end
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    return d
end
diff(a, b) = Dict(k => get(b, k, 0) - get(a, k, 0) for k in union(keys(a), keys(b)) if get(b, k, 0) != get(a, k, 0))
loads() = (t = @elapsed(@eval Main using CSV, DataFrames, CairoMakie); println("loads ", round(t; digits = 2), " s"))
const ORDER = get(ENV, "ORDER", "after")
ORDER == "before" && loads()
@eval using TraitDifferentialEquations, TraitWorld
const U0 = [1.0, 0.0, 0.0]
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
solve(ODEProblem(lorenz!, U0, (0.0, 1.0), [10.0, 28.0, 8 / 3]), Tsit5())
t0 = tally()
if ORDER == "after"
    loads(); t1 = tally()
    println("lost/gained by the loads (owner, module): ", sort(collect(filter(p -> p[1][2] != :other, diff(t0, t1))); by = string))
    t0 = t1
end
@eval struct Lorenz; s::Float64; r::Float64; b::Float64; end
@eval TraitDifferentialEquations.rhs!(m::Lorenz, du::Vector{Float64}, u::Vector{Float64}, t::Float64) =
    (du[1] = m.s * (u[2] - u[1]); du[2] = u[1] * (m.r - u[3]) - u[2]; du[3] = u[1] * u[2] - m.b * u[3]; nothing)
print("@implement: "); @time @eval @implement ODEModel{Float64} Lorenz
t1 = tally(); println("  new CIs: ", sort(collect(diff(t0, t1)); by = string)); t0 = t1
print("first solve: "); @time solve(Lorenz(10.0, 28.0, 8 / 3), U0, (0.0, 1.0), Tsit5())
t1 = tally(); println("  new CIs: ", sort(collect(diff(t0, t1)); by = string))
