# A second trait library loaded after TDE: is any code compiled under the policy invalidated?
using TraitDifferentialEquations
include(joinpath(ENV["TMPDIR"], "g2", "owners_lib.jl"))
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
p = [10.0, 28.0, 8 / 3]; u0 = [1.0, 0.0, 0.0]
solve(ODEProblem(lorenz!, u0, (0.0, 1.0), p), Tsit5())        # facts code exists for this session's key
pre = filter(ci -> ci.max_world == typemax(UInt) && ci.owner isa TW.FactsOwner, allcis())
t = @elapsed using TraitMakie
lost = filter(ci -> ci.max_world != typemax(UInt), pre)
println("TraitMakie loaded in ", round(t, digits = 2), " s; facts-owned valid before ", length(pre), ", lost ", length(lost))
for ci in lost; println("  LOST ", first(string(ci.def), 150)); end
rossler!(du, u, p, t) = (du[1] = -u[2] - u[3]; du[2] = u[1] + p[1] * u[2]; du[3] = p[2] + u[3] * (u[1] - p[3]); nothing)
s = @elapsed solve(ODEProblem(rossler!, u0, (0.0, 1.0), [0.2, 0.2, 5.7]), Tsit5())
println("second model function after the load: ", round(s * 1000, digits = 1), " ms")
xs = collect(range(0.0, 10.0; length = 200))
s2 = @elapsed (f = lines(xs, sin.(xs)); save(joinpath(ENV["TMPDIR"], "two.png"), f))
println("TraitMakie first PNG in the same session: ", round(s2 * 1000, digits = 1), " ms")
