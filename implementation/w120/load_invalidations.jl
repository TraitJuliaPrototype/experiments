# W-120: what a package's load invalidates. Julia's invalidation log around the load, read by event:
# a method's insertion ("jl_method_table_insert"), the membership walk's conservative pass over a
# method ("jl_method_table_disable": every instance of a replayed method and their callers, compiler
# C-88 (c)), the walk's own invalidations ("jl_membership_dispatch_walk"). For each kind: the events,
# the instances ended, by the module of the instance's method; and the instances matching a pattern.
#     julia --project=<env> load_invalidations.jl <package> [pattern]
pkg = Symbol(ARGS[1]); pat = length(ARGS) > 1 ? ARGS[2] : ""
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
@eval using $pkg
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
modof(mi::Core.MethodInstance) = mi.def isa Method ? Base.moduleroot(mi.def.module) : mi.def
# split the log into events: the entries before a tag string belong to it
events = Tuple{String,Vector{Any}}[]
cur = Any[]
for x in log
    if x isa String
        push!(events, (x, cur)); global cur = Any[]
    else
        push!(cur, x)
    end
end
println(length(log), " log entries, ", length(events), " tagged groups")
for tag in unique(first.(events))
    evs = [e for e in events if e[1] == tag]
    mis = Core.MethodInstance[x for e in evs for x in e[2] if x isa Core.MethodInstance]
    roots = [x for e in evs for x in e[2] if x isa Method]
    bymod = Dict{Any,Int}()
    for mi in unique(mis); bymod[modof(mi)] = get(bymod, modof(mi), 0) + 1; end
    println("\n", tag, ": ", length(evs), " groups, ", length(unique(roots)), " methods as the cause, ",
            length(mis), " instances ended (", length(unique(mis)), " distinct)")
    println("  by the module of the instance's method: ", join(("$m $n" for (m, n) in sort!(collect(bymod); by = last, rev = true)), ", "))
    causes = Dict{Any,Int}()
    for r in roots; causes[r] = get(causes, r, 0) + 1; end
    for (r, n) in first(sort!(collect(causes); by = last, rev = true), 12)
        println("    ", n, "×  ", first(string(r.sig), 150), "  in ", r.module)
    end
end
if !isempty(pat)
    println("\ninstances ended that match \"", pat, "\":")
    seen = Set{Any}()
    for (tag, xs) in events, x in xs
        x isa Core.MethodInstance || continue
        s = string(x.specTypes)
        (occursin(pat, s) && !(x in seen)) || continue
        push!(seen, x)
        println("  [", tag, "] ", first(s, 220))
    end
end
