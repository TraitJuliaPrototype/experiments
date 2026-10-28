# E-160 (SciML move 4) on today's TDE: symbolic access as traits. (1) values against direct reads; (2) a second
# names provider (a user's type) compiles nothing new in the getters; (4) a plain caller of the sugar infers the
# value's type.
#     julia --project=experiments/w34-sciml/move3/envC experiments/w34-sciml/move3/move4.jl
using TraitDifferentialEquations, TraitWorld
import ODECore, TraitIndexing
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
p = [10.0, 28.0, 8 / 3]
prob = ODEProblem(ODEFunction(lorenz!; sys = SymbolCache([:x, :y, :z], [:σ, :ρ, :β])), [1.0, 0.0, 0.0], (0.0, 1.0), p)
s = solve(prob, Tsit5())
println("M4 (1) sol.ps[:ρ] == p[2]: ", s.ps[:ρ] == p[2], "; sol[:z] == the third components: ", s[:z] == [u[3] for u in s.u],
        "; getstate(sol, :y) == the final y: ", getstate(s, :y) == s.u[end][2], "; no names: ",
        (try solve(ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 1.0), p), Tsit5())[:x]; "no error" catch e; sprint(showerror, e) end))
# a user's provider of names, as ModelingToolkit's system would be
@trait_module module UserSys
using TraitWorld
import TraitIndexing
export Sys3
struct Sys3 end
@implement TraitIndexing.IndexProvider Sys3 begin
    variable_index(ip, sym) = sym === :x ? 1 : sym === :y ? 2 : sym === :z ? 3 : nothing
    parameter_index(ip, sym) = sym === :σ ? 1 : sym === :ρ ? 2 : sym === :β ? 3 : nothing
end
end
using .UserSys
function newcis(f, names)
    new = Any[]; ccall(:jl_set_newly_inferred, Cvoid, (Any,), new)
    r = f()
    ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
    mods = [only(m for (id, m) in Base.loaded_modules if id.name == n) for n in names]
    return r, [count(ci -> ci isa Core.CodeInstance && (m = (ci.def isa Core.MethodInstance ? ci.def : ci.def.def).def; m isa Method && Base.moduleroot(m.module) === M), new) for M in mods]
end
prob2 = ODEProblem(ODEFunction(lorenz!; sys = Sys3()), [1.0, 0.0, 0.0], (0.0, 1.0), p)
s2 = solve(prob2, Tsit5())
r, c = newcis(() -> (s2[:z], s2.ps[:ρ], getstate(s2, :y)), ["ODECore", "TraitIndexing"])
println("M4 (2) a second provider (a user's type): equal values ", r[1] == s[:z] && r[2] == s.ps[:ρ] && r[3] == getstate(s, :y),
        "; CodeInstances of ODECore, TraitIndexing made by its first reads ", c)
# (4) a plain caller of the sugar
f1(sol) = sol.ps[:σ]
f2(sol) = sol[:x]
println("M4 (4) a plain caller infers sol.ps[:σ] as ", only(Base.return_types(f1, (typeof(s),))), " and sol[:x] as ", only(Base.return_types(f2, (typeof(s),))))
