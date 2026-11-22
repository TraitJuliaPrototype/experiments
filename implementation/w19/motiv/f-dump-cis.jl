# W-19: the valid CodeInstances (owner nothing) after `using CSV, DataFrames`, one line each (module root, instance), sorted.
#     julia --project=envs/up f-dump-cis.jl <out>
@eval using CSV, DataFrames
out = String[]
Base.visit(Core.methodtable) do m
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        isdefined(mi, :cache) || continue
        ci = mi.cache
        while true
            ci.owner === nothing && ci.max_world == typemax(UInt) && push!(out, string(nameof(Base.moduleroot(m.module)), " ", mi))
            isdefined(ci, :next) || break; ci = ci.next
        end
    end
end
sort!(out); write(ARGS[1], join(out, "\n"))
