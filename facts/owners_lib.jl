# Owner-aware G2 diagnosis: which CodeInstances (facts-owned or native) of ODECore, TDE and
# TraitWorld are invalidated by loads after TDE, and what the first solve then compiles.
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
