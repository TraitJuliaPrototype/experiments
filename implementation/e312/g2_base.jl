# E-312: why Base's plain code fails G2 (compiler §3.2), at the callees TraitWorld's check code inlines.
const CC = Base.Compiler
function why(ci::Core.CodeInstance, depth = 0)
    pad = "  "^(depth + 2)
    inl = isdefined(ci, :debuginfo) ? CC.inlined_defs!(Base.IdSet{Any}(), ci.debuginfo.edges) : (println(pad, "(no debug info: inlined callees unknown)"); Base.IdSet{Any}())
    for e in ci.edges
        e isa Core.CodeInstance || continue
        mi = CC.get_ci_mi(e)
        (mi in inl || mi.def in inl) || continue
        if (getfield(e, :flags, :monotonic)::UInt8 & 0x10) == 0
            println(pad, "inlined, not G2: ", mi.specTypes)
            depth < 3 && why(e, depth + 1)
        end
    end
    for (invokesig, item) in CC.ForwardToBackedgeIterator(ci.edges)
        if item isa Core.MethodTable
            CC.is_fact_sig(invokesig) || println(pad, "edge at a table, not a fact: ", invokesig)
        elseif item isa Core.MethodInstance
            invokesig === nothing || continue
            CC.is_fact_sig(item.specTypes) || println(pad, "edge, not a fact: ", item.specTypes)
        end
    end
end
for (f, tt) in ((push!, (Vector{String}, String)), (push!, (Vector{Any}, Vector{Any})),
                (iterate, (Base.Iterators.Enumerate{Vector{Any}},)))
    v = Vector{Any}(); f === push! && tt[1] === Vector{String} && push!(String[], "a")
    mi = Base.method_instance(f, tt)
    mi === nothing && (println(f, tt, ": no instance"); continue)
    ci = isdefined(mi, :cache) ? mi.cache : nothing
    while ci !== nothing
        fl = getfield(ci, :flags, :monotonic)::UInt8
        if ci.owner === nothing
            println(f, tt, " G2=", (fl & 0x10) != 0, " facts=", (fl & 0x20) != 0)
            (fl & 0x10) == 0 && why(ci)
        end
        ci = isdefined(ci, :next) ? ci.next : nothing
    end
end
