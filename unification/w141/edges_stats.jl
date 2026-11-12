# E-367, stage 1 (W-141), R4: how many membership edges a session's code holds, on either build, and
# the load time of the packages named. Run from a demonstrator's project:
#   julia --startup-file=no --project=. ../experiments/unification/w141/edges_stats.jl TraitWorld TraitTables
const newbuild = isdefined(Core, :implements)
t = @elapsed for p in ARGS
    Core.eval(Main, :(using $(Symbol(p))))
end
println("build: ", newbuild ? "a method per membership" : "cells", "; load of ", join(ARGS, ", "), ": ", round(t; digits = 3), " s")
function count_edges()
    neg = 0; pos = 0; cis = 0; withedge = 0
    Base.visit(Core.methodtable) do m
        m isa Method || return
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci isa Core.CodeInstance
                cis += 1
                es = ci.edges; n = 0
                for i in 1:length(es)
                    e = es[i]
                    if newbuild
                        if e === Core.methodtable && i > 1 && es[i-1] isa Type
                            u = Base.unwrap_unionall(es[i-1])
                            u isa DataType && u <: Tuple && length(u.parameters) == 3 && u.parameters[1] === typeof(Core.implements) && (neg += 1; n += 1)
                        elseif e isa Method && e.name === :implements
                            pos += 1; n += 1
                        end
                    else
                        e isa Core.MembershipCell && (neg += 1; n += 1)
                        e isa Core.MembershipEntry && (pos += 1; n += 1)
                    end
                end
                n > 0 && (withedge += 1)
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
    return (; cis, withedge, neg, pos)
end
println("code instances and their membership edges: ", count_edges())
newbuild && println("methods of Core.implements: ", length(methods(Core.implements)))
