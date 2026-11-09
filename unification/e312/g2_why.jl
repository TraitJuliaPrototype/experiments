# E-312: why a CodeInstance's record fails G2 (compiler §3.2): its dispatch edges not at a fact signature,
# and its inlined callees whose own record fails G2.  julia --project=<env> g2_why.jl <script> <args…>
script = abspath(popfirst!(ARGS))
include(script)
const CC = Base.Compiler
const TW = only(m for m in values(Base.loaded_modules) if nameof(m) === :TraitWorld)
function why(ci::Core.CodeInstance)
    inl = CC.inlined_defs!(Base.IdSet{Any}(), ci.debuginfo.edges)
    for e in ci.edges
        e isa Core.CodeInstance || continue
        mi = CC.get_ci_mi(e)
        (mi in inl || mi.def in inl) || continue
        (getfield(e, :flags, :monotonic)::UInt8 & 0x10) == 0 && println("    inlined, not G2: ", mi.specTypes)
    end
    for (invokesig, item) in CC.ForwardToBackedgeIterator(ci.edges)
        if item isa Core.MethodTable
            CC.is_fact_sig(invokesig) || println("    edge at a table, not a fact: ", invokesig)
        elseif item isa Core.MethodInstance
            invokesig === nothing || continue
            CC.is_fact_sig(item.specTypes) || println("    edge, not a fact: ", item.specTypes)
        end
    end
end
for f in (TW._sig_alternatives, TW._check_contract!, TW._check_pattern_member)
    for m in methods(f), mi in Base.specializations(m)
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            fl = getfield(ci, :flags, :monotonic)::UInt8
            if ci.owner === nothing && (fl & 0x10) == 0
                println(nameof(f), " ", mi.specTypes, " facts=", (fl & 0x20) != 0)
                why(ci)
            end
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
end
