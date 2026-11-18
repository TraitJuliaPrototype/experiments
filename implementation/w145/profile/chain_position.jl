function allm(mod); out = Method[]; Base.visit(Core.methodtable) do m; Base.moduleroot(m.module) === mod && push!(out, m); end; out; end
tw = unsafe_load(cglobal(:jl_typeinf_world, UInt))
println("typeinf world ", Int(tw), ", world now ", Int(Base.get_world_counter()))
pos = Int[]; dup = 0; dupinv = 0; nmi = 0
for m in allm(Base.Compiler), mi in Base.specializations(m)
    isdefined(mi, :cache) || continue
    global nmi += 1
    n = 0; at = 0; v = 0; vi = 0; ci = mi.cache
    while true
        n += 1
        if ci.owner === nothing && ci.min_world <= tw <= ci.max_world
            v += 1
            if ci.invoke != C_NULL; vi += 1; at == 0 && (at = n); end
        end
        isdefined(ci, :next) || break; ci = ci.next
    end
    at > 0 && push!(pos, at); v > 1 && (global dup += 1); vi > 1 && (global dupinv += 1)
end
sort!(pos)
println(nmi, " instances; with runnable code in the typeinf world ", length(pos), ": position mean ", round(sum(pos)/length(pos); digits=2), ", at 1: ", count(==(1), pos), ", beyond 4: ", count(>(4), pos), ", max ", pos[end])
println("instances with more than one valid CodeInstance in that world: ", dup, "; with more than one runnable: ", dupinv)
