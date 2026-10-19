const LOADS = get(ENV, "LOADS", "1") == "1"
LOADS && (t = @elapsed(@eval Main using CSV, DataFrames, CairoMakie); println("loads ", round(t; digits = 2), " s"))
@eval using TraitDifferentialEquations, TraitWorld
const U0 = [1.0, 0.0, 0.0]
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
solve(ODEProblem(lorenz!, U0, (0.0, 1.0), [10.0, 28.0, 8 / 3]), Tsit5())
owner(ci) = ci isa Core.CodeInstance ? ci.owner : (ci isa Core.MethodInstance ? :mi : typeof(ci))
function report(label, invs)
    # entries: (mi_or_ci, depth) ... then a trigger (method + "jl_method_table_insert" / "invalidate_mt_cache" etc.)
    n = Dict{Any,Int}(); trig = Dict{String,Int}()
    i = 1
    for x in invs
        if x isa Core.CodeInstance || x isa Core.MethodInstance
            k = owner(x); n[k] = get(n, k, 0) + 1
        elseif x isa Method
            s = string(x.module, ".", x.name, " ", x.sig); trig[s] = get(trig, s, 0) + 1
        end
    end
    println(label, ": invalidated by owner ", n)
    for (k, v) in first(sort(collect(trig); by = last, rev = true), 12); println("   trigger ", first(k, 160), "  ×", v); end
end
@eval struct Lorenz; s::Float64; r::Float64; b::Float64; end
invs = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
@eval TraitDifferentialEquations.rhs!(m::Lorenz, du::Vector{Float64}, u::Vector{Float64}, t::Float64) =
    (du[1] = m.s * (u[2] - u[1]); du[2] = u[1] * (m.r - u[3]) - u[2]; du[3] = u[1] * u[2] - m.b * u[3]; nothing)
report("rhs! method", copy(invs)); empty!(invs)
print("@implement: "); @time @eval @implement ODEModel{Float64} Lorenz
report("@implement", copy(invs)); empty!(invs)
print("first solve: "); @time solve(Lorenz(10.0, 28.0, 8 / 3), U0, (0.0, 1.0), Tsit5())
report("first solve", copy(invs)); empty!(invs)
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
