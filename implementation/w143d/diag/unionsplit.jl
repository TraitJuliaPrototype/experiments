# W-143d (E-540): the culprits with a fault whose signature has a top-level union whose splits are facts (the
# census's group "record: a top-level union"): the method, the fault, the cones it is in.
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
rows = Tuple{Int,String,String}[]
for (y, k) in S.culprit, f in get(S.fcache, y, Fault[])
    f.kind !== :mi && splits_fact(f.sig) && push!(rows, (get(S.incone, y, 0), first(string(y.def.specTypes), 150), string(f.kind, " ", first(string(f.sig), 120))))
end
for r in sort(rows; rev = true); println(lpad(r[1], 5), "  ", r[2], "\n        ", r[3]); end
