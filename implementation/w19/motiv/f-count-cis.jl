# W-19: the system image's MethodInstances and CodeInstances (owner nothing), and by module root the five largest
# differences are read from two runs' output.
nmi = 0; nci = 0; by = Dict{Symbol,Int}()
Base.visit(Core.methodtable) do m
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        global nmi += 1
        isdefined(mi, :cache) || continue
        ci = mi.cache
        while true
            if ci.owner === nothing
                global nci += 1
                r = nameof(Base.moduleroot(m.module)); by[r] = get(by, r, 0) + 1
            end
            isdefined(ci, :next) || break; ci = ci.next
        end
    end
end
println("MethodInstances ", nmi, ", CodeInstances ", nci, " | ", join(("$k $v" for (k, v) in sort!(collect(by); by = last, rev = true)), ", "))
