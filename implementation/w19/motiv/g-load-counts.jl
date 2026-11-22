# W-19, third part: what the load of `using CSV, DataFrames` does with the backedges (GT-34). Upstream CSV and
# DataFrames, compiled plainly (envs/up).
#     julia --project=envs/up g-load-counts.jl edges   the session's backedges after the load, by kind; the loaded
#                                                       CodeInstances' forward edges, by kind
#     julia --project=envs/up g-load-counts.jl inval   the invalidations the load records (both sides), by tag
# `inval` switches the invalidation log on, which changes what validation does (it does not stop at the first
# failed edge): run it apart from any timing.
const mode = ARGS[1]
if mode == "inval"
    inv_c = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
    Base.Compiler.ReinferUtils.debug_method_invalidation(true)
    @eval using CSV, DataFrames
    inv_j = Base.Compiler.ReinferUtils._jl_debug_method_invalidation[]
    ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
    tags = Dict{String,Int}()
    for list in (inv_c, inv_j), x in list
        x isa String && (tags[x] = get(tags, x, 0) + 1)
    end
    ninst(list) = count(x -> x isa Core.CodeInstance || x isa Core.MethodInstance, list)
    println("invalidation log: C side ", length(inv_c), " entries (instances ", ninst(inv_c), "), validation side ",
            length(inv_j), " entries (instances ", ninst(inv_j), ")")
    for (k, v) in sort!(collect(tags); by = last, rev = true)
        println("  ", rpad(k, 28), v)
    end
    exit()
end
@eval using CSV, DataFrames
sysmods = Set{Module}([Core, Base, Main])
for m in Base.loaded_modules_array()
    # a module of the system image: its package was loaded before CSV
    Base.moduleroot(m) === m && pkgdir(m) === nothing && push!(sysmods, m)
end
insys(m::Module) = Base.moduleroot(m) in sysmods || startswith(string(pathof(Base.moduleroot(m)) === nothing ? "" : pathof(Base.moduleroot(m))), Sys.STDLIB)
be_plain = 0; be_invoke = 0; be_sig = 0; mis_with_be = 0
ci_pkg = 0; ci_pkg_edges = 0; edge_items = 0; sigtriples = 0; sigtriples_wider = 0; maxedges = 0
Base.visit(Core.methodtable) do m
    global be_plain, be_invoke, be_sig, mis_with_be, ci_pkg, ci_pkg_edges, edge_items, sigtriples, sigtriples_wider, maxedges
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        if isdefined(mi, :backedges)
            mis_with_be += 1
            bes = mi.backedges; i = 1
            while i <= length(bes)
                x = bes[i]
                if x isa Core.CodeInstance
                    be_plain += 1; i += 1
                elseif x isa Core.SimpleVector
                    be_sig += 1; i += 2
                else
                    be_invoke += 1; i += 2
                end
            end
        end
        isdefined(mi, :cache) || continue
        insys(m.module) && continue
        ci = mi.cache
        while true
            if ci.owner === nothing && ci.max_world == typemax(UInt)
                ci_pkg += 1
                e = ci.edges
                if !isempty(e)
                    ci_pkg_edges += 1; edge_items += length(e); maxedges = max(maxedges, length(e))
                    j = 1
                    while j <= length(e)
                        if e[j] === 1 && j + 2 <= length(e) && (e[j+2] isa Core.CodeInstance || e[j+2] isa Core.MethodInstance)
                            sigtriples += 1
                            c = e[j+2]; cmi = c isa Core.CodeInstance ? c.def : c
                            cmi isa Core.ABIOverride && (cmi = cmi.def)
                            (e[j+1] isa Type && cmi.specTypes !== e[j+1]) && (sigtriples_wider += 1)
                            j += 3
                        else
                            j += 1
                        end
                    end
                end
            end
            isdefined(ci, :next) || break; ci = ci.next
        end
    end
end
println("session backedges after the load: MethodInstances with backedges ", mis_with_be, " | ordinary ", be_plain,
        ", invoke ", be_invoke, ", by the call's signature ", be_sig)
println("the packages' valid CodeInstances ", ci_pkg, ", with edges ", ci_pkg_edges, ", edge items ", edge_items,
        " (largest ", maxedges, "), one-match triples ", sigtriples, " of which at an instance wider than the call ", sigtriples_wider)
