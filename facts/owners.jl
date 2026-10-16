# Owner-aware G2 diagnosis: which CodeInstances (facts-owned or native) of ODECore, TDE and
# TraitWorld are invalidated by loads after TDE, and what the first solve then compiles.
order = ARGS[1]
order == "before" && (using CSV, DataFrames, CairoMakie)
using TraitDifferentialEquations
const TDE = TraitDifferentialEquations
const TW = TDE.TraitWorld
cls(m) = m === TDE.ODECore ? :ODECore : m === TDE ? :TDE : Base.moduleroot(m) === TW ? :TraitWorld : Base.moduleroot(m) === Base ? :Base : :other
function allcis()
    out = Core.CodeInstance[]
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                push!(out, ci)
                isdefined(ci, :next) || break
                ci = ci.next
            end
        end
    end
    out
end
ownername(ci) = ci.owner === nothing ? :native : nameof(typeof(ci.owner))
function tally(cis; valid_only = true)
    d = Dict{Tuple{Symbol,Symbol},Int}()
    for ci in cis
        valid_only && ci.max_world != typemax(UInt) && continue
        m = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
        m.def isa Method || continue
        k = (cls(m.def.module), ownername(ci))
        d[k] = get(d, k, 0) + 1
    end
    sort(collect(d))
end
pre = filter(ci -> ci.max_world == typemax(UInt), allcis())
order == "after" && (using CSV, DataFrames, CairoMakie)
lost = filter(ci -> ci.max_world != typemax(UInt), pre)
println(order, ": valid before loads ", length(pre), "; invalidated by loads, by (module, owner): ")
for (k, v) in tally(lost; valid_only = false); k[1] in (:ODECore, :TDE, :TraitWorld) && println("   ", k, " ", v); end
for ci in lost
    mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
    mi.def isa Method && cls(mi.def.module) === :ODECore && println("     ODECore lost: ", ownername(ci), " ", first(string(mi.specTypes), 150))
end
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
p = [10.0, 28.0, 8 / 3]; u0 = [1.0, 0.0, 0.0]
before = Set(allcis())
s = time(); solve(ODEProblem(lorenz!, u0, (0.0, 1.0), p), Tsit5()); e = time() - s
new = filter(ci -> !(ci in before), allcis())
println("first solve ", round(e * 1000, digits = 1), " ms; new CodeInstances by (module, owner):")
for (k, v) in tally(new; valid_only = false); println("   ", k, " ", v); end
if get(ENV, "VERBOSE", "0") == "1"
    for ci in new
        mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
        println("  new ", ownername(ci), " ", first(string(mi), 150))
    end
end
