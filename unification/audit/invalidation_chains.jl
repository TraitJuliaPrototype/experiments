# The chain report: why an instance is invalidated at a package's load. For each invalidated instance
# whose signature matches a pattern, the chain from the root the inserted method invalidated (depth 0;
# printed `?` where the log gives it only by depth) up to the instance, and the cause (the method
# instance replaced, or the method inserted). Found the chains to TraitWorld's load hooks (E-332, E-334).
#     julia-unified/julia --startup-file=no [--project=<env>] experiments/unification/audit/invalidation_chains.jl <regex> Pkg,…
# A report: it asserts nothing; it prints at most six chains.
pat = Regex(ARGS[1])
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
for p in split(ARGS[2], ',')
    Core.eval(Main, :(using $(Symbol(p))))
end
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
# entries: (mi, depth) pairs; then a cause (method or type, tag string)
i = 1; seen = 0
stack = Any[]
while i <= length(log) && seen < 6
    x = log[i]
    if x isa Core.MethodInstance && i < length(log) && log[i+1] isa Int32
        d = Int(log[i+1])
        resize!(stack, d); push!(stack, x)
        if occursin(pat, string(x.specTypes)) && d > 0
            global seen += 1
            # find the cause: the next tag string after this point
            j = i; while j <= length(log) && !(log[j] isa String); j += 1; end
            println("== depth $d, cause: ", j <= length(log) ? (log[j-1], log[j]) : "?")
            for k in 1:length(stack)
                isassigned(stack, k) || (println("  ", k-1, " ?"); continue)
                println("  ", k-1, " ", first(string(stack[k].specTypes), 180))
            end
        end
        global i += 2
    else
        if !(x isa String) && i < length(log) && log[i+1] isa String
            empty!(stack)
        end
        global i += 1
    end
end
