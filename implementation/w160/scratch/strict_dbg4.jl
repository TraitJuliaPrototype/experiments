using TraitWorld
const CC = Core.Compiler
const ORIG = CC.record_memberships!
@eval CC function record_memberships!(sv::InferenceState, @nospecialize(a), @nospecialize(b))
    entries = ccall(:jl_membership_entries_for, Any, (Any, Any, UInt), a, b, frame_world(sv))::SimpleVector
    if !isempty(entries) && sv.linfo.def isa Method && sv.linfo.def.name === :sq
        Core.println("record a=", a, " b=", b, " entries=", length(entries))
        for (i, fr) in enumerate(Base.stacktrace())
            i > 8 && break
            Core.println("   ", fr)
        end
    end
    isempty(entries) && return false
    for e in entries
        e = e::Core.MembershipEntry
        getfield(e, :method) isa Method || return false
    end
    for e in entries
        e = e::Core.MembershipEntry
        update_valid_age!(sv, WorldRange(getfield(e, :min_world), getfield(e, :max_world, :monotonic)))
        m = getfield(e, :method)::Method
        msig = m.sig
        sparams = (ccall(:jl_type_intersection_with_env, Any, (Any, Any), msig, msig)::SimpleVector)[2]::SimpleVector
        mi = specialize_method(m, msig, sparams)
        edges = sv.edges
        found = false
        for i in 2:length(edges)
            if edges[i] === mi && edges[i-1] === msig
                found = true
                break
            end
        end
        found || push!(edges, msig, mi)
    end
    return true
end
module StrictLib
using TraitWorld
@trait_module
@trait SBuf begin
    svals(r::SBuf)::Vector{Float64}
end
struct Buf; v::Vector{Float64}; end
svals(b::Buf) = b.v
@implement SBuf Buf
sq(b::SBuf) = (s = 0.0; for x in svals(b); s += abs2(x); end; s)
end
b = StrictLib.Buf([1.0,2.0,3.0])
@show StrictLib.sq(b)
