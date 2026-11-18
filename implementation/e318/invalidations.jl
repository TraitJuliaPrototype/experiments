# E-318: what invalidates the REPL's `show` of a String at its stream when the forks load.
# julia --project=<forks env> invalidations.jl [packages...]
using REPL
pkgs = isempty(ARGS) ? ["CSV", "DataFrames"] : ARGS
ins = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
val = Base.Compiler.ReinferUtils.debug_method_invalidation(true)
for p in pkgs
    Core.eval(Main, :(using $(Symbol(p))))
end
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
Base.Compiler.ReinferUtils.debug_method_invalidation(false)
println("insertion log: ", length(ins), " entries; validation log: ", length(val), " entries")
# the insertion log: invalidated instances, each followed by depth ints, a tree ending at (method, "jl_method_table_insert")
function trees(log)
    out = []; cur = Any[]
    i = 1
    while i <= length(log)
        x = log[i]
        if x isa Method && i < length(log) && log[i+1] isa String
            push!(out, (x, log[i+1], cur)); cur = Any[]; i += 2; continue
        end
        x isa Core.MethodInstance && push!(cur, x)
        i += 1
    end
    out
end
for pat in ("LimitIO", "show), Base.IOContext", "TTYTerminal")
    println("== instances naming ", pat)
    for (m, why, mis) in trees(ins)
        hits = [mi for mi in mis if occursin(pat, string(mi.specTypes))]
        isempty(hits) && continue
        println("  by ", m, " (", why, "): ", length(mis), " instances, ", length(hits), " naming it")
        for h in first(hits, 3); println("      ", h.specTypes); end
    end
end
println("== the methods whose insertion invalidated most")
cnt = Dict{Any,Int}()
for (m, why, mis) in trees(ins); cnt[m] = get(cnt, m, 0) + length(mis); end
for (m, n) in first(sort(collect(cnt); by = last, rev = true), 15); println("  ", n, "  ", m); end
println("== validation log entries naming LimitIO or show at a String")
for x in val
    s = string(x)
    (occursin("LimitIO", s) || occursin("typeof(Base.show), Base.IOContext", s)) && println("  ", first(s, 250))
end
