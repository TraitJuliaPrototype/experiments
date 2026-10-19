function tally()
    d = Dict{Tuple{Any,Symbol},Int}()
    Base.visit(Core.methodtable) do m
        r = nameof(Base.moduleroot(m.module))
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                if ci.max_world == typemax(UInt)
                    k = (ci.owner isa Symbol || ci.owner === nothing ? ci.owner : nameof(typeof(ci.owner)), r in (:Base, :Core, :TraitWorld, :TraitMakie, :TraitDifferentialEquations) ? r : :other)
                    d[k] = get(d, k, 0) + 1
                end
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    return d
end
diff(a, b) = Dict(k => get(b, k, 0) - get(a, k, 0) for k in union(keys(a), keys(b)) if get(b, k, 0) != get(a, k, 0))
