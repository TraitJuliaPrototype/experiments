# E-304 (W-125, stage 3's item 2): what validation checks, split by the G2 bit and the policy. For each package in
# ARGS, in order: the CodeInstances that its load brings from images (flag FROM_IMAGE, not present before the
# load), counted and their edges by kind, grouped by G2 (flag 0x10) and facts (flag 0x20); with the load's time.
# Usage: julia --project=<env> g2_split.jl Pkg1 Pkg2 ...
const FROM_IMAGE = 0x04; const G2 = 0x10; const FACTS = 0x20

function all_cis()
    out = Base.IdSet{Core.CodeInstance}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi === nothing && continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                push!(out, ci)
                isdefined(ci, :next) || break
                ci = ci.next
            end
        end
    end
    return out
end

function edge_kinds!(kinds::Dict{String,Int}, ci::Core.CodeInstance)
    e = ci.edges
    j = 1
    while j <= length(e)
        x = e[j]
        k = x isa Core.CodeInstance ? "CodeInstance" : x isa Core.MethodInstance ? "MethodInstance" :
            x isa Int ? "call by signature" : x isa Core.MembershipCell ? "MembershipCell" :
            x isa Core.MembershipEntry ? "MembershipEntry" : x isa Core.Binding ? "Binding" :
            x isa Type ? "invoke signature" : string(typeof(x))
        kinds[k] = get(kinds, k, 0) + 1
        j += x isa Int ? 2 + abs(x) : (x isa Type ? 2 : 1)
    end
end

function report(p)
    before = all_cis()
    t = @elapsed Core.eval(Main, :(using $(Symbol(p))))
    groups = Dict{String,Tuple{Int,Dict{String,Int}}}()
    for ci in all_cis()
        ci in before && continue
        f = ci.flags
        (f & FROM_IMAGE) != 0 || continue
        g = string((f & G2) != 0 ? "G2" : "not G2", ", ", (f & FACTS) != 0 ? "facts" : "plain")
        n, kinds = get(groups, g, (0, Dict{String,Int}()))
        edge_kinds!(kinds, ci)
        groups[g] = (n + 1, kinds)
    end
    println("== ", p, ": load ", round(t, digits = 3), " s")
    for (g, (n, kinds)) in sort(collect(groups); by = first)
        tot = sum(values(kinds); init = 0)
        println("  ", rpad(g, 16), lpad(n, 6), " instances, ", lpad(tot, 7), " edges: ",
                join(["$k $v" for (k, v) in sort(collect(kinds); by = last, rev = true)], ", "))
    end
end
foreach(report, ARGS)
