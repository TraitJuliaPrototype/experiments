# E-312: the CodeInstance a caller's edge names against the one in the callee's cache
const CC = Base.Compiler
for (f, tt) in ((Base._push!, (Vector{String}, String)), (push!, (Vector{String}, String)))
    mi = Base.method_instance(f, tt)
    ci = mi.cache
    while ci !== nothing
        fl = getfield(ci, :flags, :monotonic)::UInt8
        println(f, tt, " CI world=", ci.min_world, ":", ci.max_world == typemax(UInt) ? "∞" : ci.max_world, " G2=", (fl & 0x10) != 0, " debuginfo=", isdefined(ci, :debuginfo))
        for e in ci.edges
            e isa Core.CodeInstance || continue
            emi = CC.get_ci_mi(e)
            efl = getfield(e, :flags, :monotonic)::UInt8
            incache = false; c2 = emi.cache
            while c2 !== nothing; c2 === e && (incache = true); c2 = isdefined(c2, :next) ? c2.next : nothing; end
            println("    edge ", emi.specTypes, " world=", e.min_world, ":", e.max_world == typemax(UInt) ? "∞" : e.max_world,
                    " G2=", (efl & 0x10) != 0, " debuginfo=", isdefined(e, :debuginfo), " in its cache=", incache)
        end
        ci = isdefined(ci, :next) ? ci.next : nothing
    end
end
