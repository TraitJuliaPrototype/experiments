# W-19, up/19: the backedges by the call's own signature in a session's code (the system image's).
#   julia --startup-file=no f-callsig-census.jl
# Counts every MethodInstance backedge entry by kind: an ordinary caller, an `invoke` (a type), a call by
# its own signature (a one-element svec, up/19's form), and lists the callee methods with the most
# backedges by the call's signature. On a build without up/19 the third kind is 0.
plain = 0; invk = 0; callsig = 0
bymeth = Dict{Method,Int}()
Base.visit(Core.methodtable) do m
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        isdefined(mi, :backedges) || continue
        be = mi.backedges
        i = 1
        while i <= length(be)
            x = be[i]
            if x isa Core.CodeInstance
                global plain += 1; i += 1
            elseif x isa Core.SimpleVector
                global callsig += 1; bymeth[m] = get(bymeth, m, 0) + 1; i += 2
            else
                global invk += 1; i += 2
            end
        end
    end
end
println("backedge entries: ordinary ", plain, ", invoke ", invk, ", by the call's signature ", callsig)
for (m, n) in first(sort!(collect(bymeth); by = last, rev = true), 15)
    println(lpad(n, 6), "  ", m)
end
