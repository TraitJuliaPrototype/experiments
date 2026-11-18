# W-146 (4) (compiler C-88 (c)): which methods the membership walk's conservative path replays at a
# load, and how many instances each ends.
#     julia --project=<env> disabled.jl <package> [<package> …]
# In Julia's invalidation log the conservative path writes the instances it ends, then the method and
# "jl_method_table_disable". Prints each such method with its signature and the count before it.
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
for p in ARGS; @eval using $(Symbol(p)); end
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
counts = Dict{Method,Int}(); n = 0; events = Dict{String,Int}()
for (i, x) in enumerate(log)
    if x isa Core.MethodInstance || x isa Core.CodeInstance
        global n += 1
    elseif x isa String
        events[x] = get(events, x, 0) + 1
        if x == "jl_method_table_disable" && i > 1 && log[i-1] isa Method
            counts[log[i-1]] = get(counts, log[i-1], 0) + n
        end
        x in ("jl_method_table_disable", "jl_method_table_insert", "jl_membership_dispatch_walk") && (global n = 0)
    end
end
println(join(ARGS, "+"), ": ", length(counts), " methods replayed conservatively; events: ", join(("$k $v" for (k, v) in sort(collect(events); by = last, rev = true)), ", "))
for (m, c) in first(sort(collect(counts); by = last, rev = true), 40)
    println(lpad(c, 6), "  ", first(string(m.sig), 170), "   [", m.module, "]")
end
