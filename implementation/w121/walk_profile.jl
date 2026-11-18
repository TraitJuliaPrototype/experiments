# E-290 (W-121, phase 1): where inside the dispatch walk at activation a load spends its time.
#     julia --project=<env> walk_profile.jl Pkg1 Pkg2 ... PkgN     # loads all but the last, profiles the last
# The main thread's samples under jl_membership_dispatch_walk, each attributed to the first matching class
# (CLASSES' order) on its stack; the rest of the load's samples as "outside the walk".
using Profile
# Each class by the frames between the walk and the leaf: the visitors' callbacks name whose visit it is.
const CLASSES = [
    ("conservative pass (every method's specializations)", ["membership_shadow_visitor", "membership_all_specializations", "jl_method_invalidate_core"]),
    ("cache tail (the whole method cache)", ["invalidate_mt_cache", "invalidate_all_mt_cache"]),
    ("instances' intersection", ["invalidate_intersecting"]),
    ("matching", ["get_intersect_matches"]),
    ("substitution, supersets", ["membership_subst_sig", "membership_superset_sets"]),
    ("missing backedges", ["invalidate_missing_backedges"]),
    ("typemap visit, unattributed", ["jl_typemap_visitor", "jl_typemap_node_visitor", "jl_typemap_array_visitor", "jl_typemap_memory_visitor"]),
]
function retrieve_stacks()
    data, lidict = Profile.retrieve()
    stacks = Vector{Vector{String}}()
    start = 1; n = length(data); i = 3
    while i <= n
        if data[i] == 0 && data[i-1] == 0 && data[i-2] in 1:3
            tid = data[i-5]; sleeping = data[i-2] != 1
            frames = @view data[start:i-6]
            start = i + 1
            if tid == 1 && !sleeping && !isempty(frames)
                push!(stacks, [string(fr.func) for ip in frames for fr in get(lidict, ip, Base.StackTraces.StackFrame[])])
            end
            i += 3; continue
        end
        i += 1
    end
    return stacks
end
pkgs = Symbol.(ARGS)
for p in pkgs[1:end-1]
    t = @elapsed Core.eval(Main, :(using $p)); println("L ", p, " ", round(t, digits = 3), " s")
end
Profile.clear(); Profile.init(n = 10^7, delay = 0.0005)
t = @elapsed @profile Core.eval(Main, :(using $(pkgs[end])))
stacks = retrieve_stacks()
function tally(stacks)
counts = Dict{String,Int}(); inwalk = 0
for st in stacks
    if any(n -> endswith(n, "jl_membership_dispatch_walk"), st)
        inwalk += 1
        w = findfirst(n -> endswith(n, "jl_membership_dispatch_walk"), st)   # stacks list the leaf first
        below = st[1:w-1]
        cls = w == 1 ? "the walk's own code (leaf cache, targets)" : "rest of the walk"
        for (c, keys) in CLASSES
            if any(name -> any(k -> endswith(name, k), keys), below); cls = c; break; end
        end
        counts[cls] = get(counts, cls, 0) + 1
    end
end
return counts, inwalk
end
counts, inwalk = tally(stacks)
println("P ", pkgs[end], " ", round(t, digits = 3), " s (profiled), ", length(stacks), " samples, ", inwalk, " in the walk (",
        round(100 * inwalk / max(length(stacks), 1), digits = 1), " %)")
for (k, v) in sort(collect(counts), by = x -> -x[2])
    println("W ", rpad(k, 46), " ", lpad(v, 6), "  ", round(100 * v / max(inwalk, 1), digits = 1), " % of the walk")
end
