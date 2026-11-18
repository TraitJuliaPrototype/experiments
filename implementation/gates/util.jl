# shared probes for the M1 gate scripts (plan §5 M1)

# all cached CodeInstances of a function, newest surface first
function all_cis(@nospecialize(f))
    out = Core.CodeInstance[]
    for m in methods(f)
        for mi in Base.specializations(m)
            isdefined(mi, :cache) || continue                       # no CodeInstance yet
            ci = getfield(mi, :cache)::Core.CodeInstance
            while ci !== nothing
                push!(out, ci)
                ci = isdefined(ci, :next) ? ci.next : nothing  # the last link's next is undefined
            end
        end
    end
    return out
end

# the world the current task is executing in
curworld() = Base.tls_world_age()

# The negatives a CodeInstance relied on (W-141; compiler §4.8): the signatures of `Core.implements` it
# holds as edges at the method table, with no method. `absence_member(sig)` is the pair's type,
# `absence_set(sig)` its set.
function absences(ci)
    es = ci.edges; out = Any[]
    for i in 1:length(es)-1
        s = es[i]
        (es[i+1] === Core.methodtable && s isa Type) || continue
        u = Base.unwrap_unionall(s)
        u isa DataType && u <: Tuple && length(u.parameters) == 3 && u.parameters[1] === typeof(Core.implements) && push!(out, s)
    end
    return out
end
_typearg(p) = (q = p.parameters[1]; q isa TypeVar ? q.ub : q)
absence_member(sig) = _typearg(Base.unwrap_unionall(sig).parameters[3])
absence_set(sig) = _typearg(Base.unwrap_unionall(sig).parameters[2])
# whether the method table keeps `ci` as a dependent of the signature `sig`
function absence_kept(sig, ci)
    be = Core.methodtable.backedges
    for k in 2:2:length(be)
        isassigned(be, k) || continue
        v = be[k]
        v isa Vector || continue
        for i in 1:2:length(v)-1
            v[i+1] === ci && v[i] == sig && return true
        end
    end
    return false
end
