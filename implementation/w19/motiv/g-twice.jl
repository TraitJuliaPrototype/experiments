# W-19, third part (F12, S2): the instances whose cache holds more than one compiled CodeInstance of the same
# owner, policy and result type valid now (code compiled twice for one result), in the system image and after
# an optional workload.   julia --startup-file=no g-twice.jl [--load]
if "--load" in ARGS
    @eval using CSV, DataFrames
end
twice = 0; extra = 0; insts = 0; ex = String[]
Base.visit(Core.methodtable) do m
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        isdefined(mi, :cache) || continue
        seen = Dict{Any,Int}()
        ci = mi.cache
        while true
            if ci.owner === nothing && ci.max_world == typemax(UInt) && ci.invoke != C_NULL
                k = ((ci.flags & 0x20) != 0, ci.rettype)
                seen[k] = get(seen, k, 0) + 1
            end
            isdefined(ci, :next) || break; ci = ci.next
        end
        global insts += 1
        n = sum(v -> v - 1, values(seen); init = 0)
        if n > 0
            global twice += 1; global extra += n
            length(ex) < 5 && push!(ex, string(mi))
        end
    end
end
println("instances ", insts, " | compiled more than once for one result: ", twice, " (", extra, " extra CodeInstances)")
foreach(e -> println("  ", e), ex)
