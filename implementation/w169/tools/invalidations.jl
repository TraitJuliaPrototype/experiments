# W-169: Julia's invalidation log (`jl_debug_method_invalidation`), summarized.
# The log's shapes on the head (src/gf.c, Compiler/src/reinfer.jl):
#   (mi, depth)*, method, "jl_method_table_insert"         a method's insertion and the code it ends
#   (mi, depth)*, method, "jl_method_table_disable"        a method's deletion
#   (mi, depth)*, method, "jl_membership_dispatch_walk"    a membership's walk and the code it ends
#   mi, "invalidate_mt_cache"                              a dispatch cache entry lowered (no code)
#   child, "verify_methods", cause                         an image's code rejected at load (validation)
#   edge, "insert_backedges_callee", codeinst, matches     an image's edge whose callee's matches changed
#   binding entries, "jl_maybe_log_binding_invalidation"
# Counts MethodInstances ended (each (mi, depth) pair), per kind, per cause, and per the ended code's root module.
rootmod(m::Module) = nameof(Base.moduleroot(m))
rootmod(mi::Core.MethodInstance) = mi.def isa Method ? rootmod(mi.def.module) : mi.def isa Module ? rootmod(mi.def) : :?
rootmod(ci::Core.CodeInstance) = rootmod(Base.get_ci_mi(ci))
rootmod(x) = :?
showcause(x) = try
    s = x isa Method ? string(x.module, ".", x.name, " ", x.sig) : x isa Core.MethodInstance ? string(x.specTypes) :
        x isa Core.CodeInstance ? string(Base.get_ci_mi(x).specTypes) : x isa Core.Binding ? "binding" : string(typeof(x), " ", x)
    first(replace(s, '\n' => ' '), 200)
catch
    string(typeof(x))
end
function summarize_invalidations(io, log; top = 12)
    kinds = Dict{String,Int}(); causes = Dict{Tuple{String,String},Int}(); roots = Dict{Symbol,Int}()
    vcauses = Dict{String,Int}(); vroots = Dict{Symbol,Int}()
    pend = Any[]; i = 1; n = length(log)
    while i <= n
        x = log[i]
        if x isa String
            if x in ("jl_method_table_insert", "jl_method_table_disable", "jl_membership_dispatch_walk")
                cause = i > 1 ? log[i-1] : nothing
                mis = [p for p in pend if p isa Core.MethodInstance || p isa Core.CodeInstance]
                kinds[x] = get(kinds, x, 0) + length(mis)
                k = (x, showcause(cause)); causes[k] = get(causes, k, 0) + length(mis)
                for p in mis; r = rootmod(p); roots[r] = get(roots, r, 0) + 1; end
                empty!(pend)
            elseif x == "invalidate_mt_cache"
                kinds[x] = get(kinds, x, 0) + 1
                isempty(pend) || pop!(pend)
            elseif x == "verify_methods"
                child = isempty(pend) ? nothing : pop!(pend)
                kinds[x] = get(kinds, x, 0) + 1
                r = rootmod(child); vroots[r] = get(vroots, r, 0) + 1
                cause = i < n ? log[i+1] : nothing
                c = showcause(cause); vcauses[c] = get(vcauses, c, 0) + 1
                i += 1
            elseif x == "insert_backedges_callee"
                isempty(pend) || pop!(pend)
                kinds[x] = get(kinds, x, 0) + 1
                i += 2
            else
                kinds[x] = get(kinds, x, 0) + 1
                empty!(pend)
            end
        elseif !(x isa Integer)
            push!(pend, x)
        end
        i += 1
    end
    println(io, "INVAL log entries ", n, " | ", join(["$k $v" for (k, v) in sort(collect(kinds); by = last, rev = true)], ", "))
    println(io, "INVAL ended code by root module: ", join(["$k $v" for (k, v) in first(sort(collect(roots); by = last, rev = true), top)], ", "))
    for ((k, c), v) in first(sort(collect(causes); by = last, rev = true), top)
        println(io, "INVAL cause\t", v, "\t", k, "\t", c)
    end
    isempty(vroots) || println(io, "INVAL rejected at load by root module: ", join(["$k $v" for (k, v) in first(sort(collect(vroots); by = last, rev = true), top)], ", "))
    for (c, v) in first(sort(collect(vcauses); by = last, rev = true), top)
        println(io, "INVAL verify cause\t", v, "\t", c)
    end
end
