# W-143e (E-541; compiler C-160): the culprits of the census's group "a top-level union whose splits are facts", each
# fault read in the caller's record: the edge group that holds the instance named (a call's lookup: the number of
# matches, the call's signature, its callees; an `invoke` edge; an instance alone), so that its shape is seen: one
# match at a wider instance (which compiler §1.2 splits), several matches at a call whose signature is no fact
# (the union is a matched method's own signature met with the call's), or an instance alone.
#     CENSUS_WORK=table julia --project=envs/<env> diag/edges_of.jl <csv>
include(joinpath(@__DIR__, "..", "census_lib.jl"))
const csv = ARGS[1]
S = census_session(csv)
function splits_fact(@nospecialize(s))
    s isa DataType || return false
    ps = s.parameters; any(p -> p isa Union, ps) || return false
    any(Base.isvarargtype, ps) && return false
    n = prod(p -> p isa Union ? length(Base.uniontypes(p)) : 1, ps)
    n <= C.MAX_FACT_SPLITS || return false
    return all(c -> C.is_fact_sig(Tuple{c...}), Iterators.product((p isa Union ? Base.uniontypes(p) : Any[p] for p in ps)...))
end
inst(e) = e isa Core.CodeInstance ? e.def : e
short(@nospecialize(x), n = 110) = first(x isa Core.CodeInstance ? "CI " * string(x.def.specTypes) :
                                         x isa Core.MethodInstance ? "MI " * string(x.specTypes) : string(x), n)
# the edge group of `edges` that holds the instance whose specTypes is `sig`
function group_of(edges, @nospecialize(sig))
    i = 1
    while i <= length(edges)
        e = edges[i]
        if e isa Int
            n = abs(e); grp = edges[i:min(end, i + 1 + n)]
            any(x -> (m = inst(x); m isa Core.MethodInstance && m.specTypes === sig), grp[3:end]) &&
                return "lookup: $(e) match$(abs(e) == 1 ? "" : "es")$(e < 0 ? " (not covering)" : "") at " * short(grp[2], 120) *
                       join(["\n              callee " * short(x) for x in grp[3:end]])
            i += 2 + n
        elseif e isa Type && i < length(edges) && !(edges[i+1] isa Type)
            m = inst(edges[i+1])
            m isa Core.MethodInstance && m.specTypes === sig &&
                return "invoke at " * short(e) * " -> " * short(edges[i+1])
            i += 2
        else
            m = inst(e)
            m isa Core.MethodInstance && m.specTypes === sig && return "an instance alone: " * short(e)
            i += 1
        end
    end
    return "not found"
end
rows = Tuple{Int,String}[]
for (y, k) in S.culprit, f in get(S.fcache, y, Fault[])
    f.kind !== :mi && splits_fact(f.sig) || continue
    others = [string(g.kind, " ", first(string(g.sig), 100)) for g in S.fcache[y] if g !== f]
    push!(rows, (get(S.incone, y, 0), string(first(string(y.def.specTypes), 140), "\n   fault ", f.kind, " ", first(string(f.sig), 120),
                 "\n   its edge group: ", group_of(y.edges, f.sig), "\n   the culprit's other faults: ",
                 isempty(others) ? "none" : join(others, "\n      "))))
end
println("culprits with a fault at a top-level union whose splits are facts: ", length(unique(r[2] for r in rows)))
for r in sort(rows; rev = true); println(lpad(r[1], 5), "  ", r[2]); end
