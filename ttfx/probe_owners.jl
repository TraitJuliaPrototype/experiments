# E-169: after the load, the CodeInstances present by owner (images' code included), and their edges.
const _MT = isdefined(Core, :GlobalMethods) ? Core.GlobalMethods : Core.methodtable
function census()
    n = Dict{Any,Int}(); e = Dict{Any,Int}()
    Base.visit(_MT) do m
        for mi in Base.specializations(m)
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci isa Core.CodeInstance
                n[ci.owner] = get(n, ci.owner, 0) + 1
                ed = isdefined(ci, :edges) ? ci.edges : Core.svec()
                e[ci.owner] = get(e, ci.owner, 0) + length(ed)
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
    n, e
end
n0, e0 = census()
@eval using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, CairoMakie
n1, e1 = census()
for k in union(keys(n0), keys(n1))
    println(rpad(string(k), 40), " CodeInstances +", get(n1, k, 0) - get(n0, k, 0), "  edge entries +", get(e1, k, 0) - get(e0, k, 0))
end
