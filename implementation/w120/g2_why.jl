# W-120: why an instance a session compiled is not kept by an image: its record against G2 (compiler
# §3.2). Runs a script (its `main`), then for each instance of the named functions compiled under
# Julia's own owner: the flags, and where G2 fails, the dispatch edges that are not at a fact signature
# and the inlined callees whose own record fails.
#     julia --project=<env> g2_why.jl <script.jl> <Module.function> [...]   (the script's args after --)
script = abspath(popfirst!(ARGS))
i = findfirst(==("--"), ARGS)
fnames = i === nothing ? copy(ARGS) : ARGS[1:i-1]
sargs = i === nothing ? String[] : ARGS[i+1:end]
include(script)
redirect_stdout(devnull) do; Base.invokelatest(main, sargs); end
const CC = Base.Compiler
function resolve(path::String)
    parts = Symbol.(split(path, "."))
    m = only(x for x in values(Base.loaded_modules) if nameof(x) === parts[1])
    for p in parts[2:end-1]; m = getglobal(m, p); end
    return getglobal(m, parts[end])
end
function why(ci::Core.CodeInstance, depth::Int = 0, seen = Base.IdSet{Any}())
    ci in seen && return
    push!(seen, ci)
    pad = "        " * "  "^depth
    inl = CC.inlined_defs!(Base.IdSet{Any}(), ci.debuginfo.edges)
    for e in ci.edges
        e isa Core.CodeInstance || continue
        mi = CC.get_ci_mi(e)
        (mi in inl || mi.def in inl) || continue
        if (getfield(e, :flags, :monotonic)::UInt8 & 0x10) == 0
            println(pad, "inlined, not G2: ", first(string(mi.specTypes), 180))
            depth < 6 && why(e, depth + 1, seen)        # down to the edge that fails
        end
    end
    for (invokesig, item) in CC.ForwardToBackedgeIterator(ci.edges)
        if item isa Core.MethodTable
            CC.is_fact_sig(invokesig) || println(pad, "EDGE at a table, not a fact: ", first(string(invokesig), 260))
        elseif item isa Core.MethodInstance
            invokesig === nothing || continue
            CC.is_fact_sig(item.specTypes) || println(pad, "EDGE, not a fact: ", first(string(item.specTypes), 260))
        end
    end
end
for path in fnames
    f = resolve(path)
    for m in methods(f), mi in Base.specializations(m)
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            fl = getfield(ci, :flags, :monotonic)::UInt8
            if ci.owner === nothing
                println(path, " | ", first(string(mi.specTypes), 160))
                println("      facts=", (fl & 0x20) != 0, " G2=", (fl & 0x10) != 0, " image=", (fl & 0x04) != 0,
                        " world=", Int(ci.min_world), ":", ci.max_world == typemax(UInt) ? "∞" : string(Int(ci.max_world)))
                (fl & 0x10) == 0 && ci.max_world == typemax(UInt) && why(ci)
            end
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
end
