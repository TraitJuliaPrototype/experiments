# E-280: the code invalidated while a workload runs, with the membership walk's code invalidation on
# (the stopgap, compiler C-18 as it was) or off (the guards, W-112), and the calls that carry a guard.
# Usage: julia --project=TraitWorld-unified e280.jl <workload.jl> on|off
mode = ARGS[2]
ccall(:jl_set_membership_walk_invalidates, Cint, (Cint,), mode == "on" ? 1 : 0)
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
include(abspath(ARGS[1]))
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
invalidated = IdSet{Any}()
for x in log
    (x isa Core.CodeInstance || x isa Core.MethodInstance) && push!(invalidated, x)
end
# the guarded CodeInstances now cached, and the cells their guards read
guarded = 0
cells = IdSet{Any}()
Base.visit(Core.methodtable) do m
    for mi in Base.specializations(m)
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            if ci.owner === nothing && isdefined(ci, :edges)
                cs = [e for e in ci.edges if e isa Core.MembershipCell]
                isempty(cs) || (global guarded += 1)
                foreach(c -> push!(cells, c), cs)
            end
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
end
println("walk invalidates code: $mode")
println("method or code instances invalidated during the run: ", length(invalidated))
println("CodeInstances with a guard: $guarded; membership cells they read: ", length(cells),
        ", open: ", count(c -> c.min_world != typemax(UInt), cells))
