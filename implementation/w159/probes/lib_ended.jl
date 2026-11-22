# W-159 probe: which of the library's own instances a port's load ends, and the method insertion or the load-time
# event that ends each (Julia's invalidation log, read as SnoopCompile reads it).
#     julia --project=<env> lib_ended.jl <Pkg>
using TraitWorld
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
@eval using $(Symbol(ARGS[1]))
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
isroot(x) = x isa Core.MethodInstance && x.def isa Method && Base.moduleroot(x.def.module) === TraitWorld
# the log: runs of (instance, depth) closed by (cause, tag); print each run that holds a library instance
i = 1; run = Any[]
while i <= length(log)
    global i, run
    x = log[i]
    if i < length(log) && log[i + 1] isa String
        tag = log[i + 1]
        if any(y -> y isa Core.MethodInstance && isroot(y), run)
            println("CAUSE ", tag, " ", first(string(x), 200))
            for y in run; y isa Core.MethodInstance && println("    ", isroot(y) ? "LIB " : "    ", first(string(y), 160)); end
        end
        run = Any[]; i += 2
    else
        push!(run, x); i += 1
    end
end
