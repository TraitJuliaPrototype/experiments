# W-170 (E-538), open issue 255 (a), measured only: the membership walk at the ODE port's load, by the member's
# origin. After `using TraitWorld, TraitDifferentialEquations` (the program's load, E-536), every membership the
# loaded images activated is walked again, one at a time, with the walk's invalidation off
# (`jl_set_membership_walk_invalidates(0)`), timed and counted (`jl_membership_stat`: methods replayed, methods
# examined, cache entries lowered). Each member is classed by the module that defines its type:
#   new      a package of the ODE port's load (ODECore, TraitRodas, TraitIndexing, TraitArrayTools,
#            TraitNonlinearSolve, TraitDifferentialEquations): a type new with the load (facts §2.2: its membership
#            ends no code compiled before the load)
#   library  TraitWorld's own types (loaded in the same `using`)
#   foreign  every other type (Core, Base, the standard libraries, ForwardDiff, ...)
# A proxy, and what it does not model: the walk runs in the loaded state, so it meets the methods of every image
# (at the load, a membership's walk meets the methods loaded up to its image); with the invalidation off it does not
# invalidate, as the load's walk does where code ends; a cache entry it lowers stays lowered for the walks after it.
#     julia --project=<env> probe255.jl
using TraitWorld, TraitDifferentialEquations
const NEW = Set(["ODECore", "TraitRodas", "TraitIndexing", "TraitArrayTools", "TraitNonlinearSolve", "TraitDifferentialEquations"])
origin(@nospecialize(T)) = (u = Base.unwrap_unionall(T); u isa DataType ? string(nameof(Base.moduleroot(u.name.module))) : "?")
klass(@nospecialize(T)) = (o = origin(T); o in NEW ? "new" : o == "TraitWorld" ? "library" : "foreign")
stat() = [ccall(:jl_membership_stat, Csize_t, (Cint,), k) for k in 1:5]       # replays, visits, skips, invalidations, lowerings
list = ccall(:jl_activated_memberships, Any, ())::Core.SimpleVector
println("R activated memberships: ", length(list))
let s = stat(), d = ccall(:jl_membership_stat, Csize_t, (Cint,), 0)
    println("R at the load itself (the runtime's counters, every walk of the load): walks ", d, " | replayed ", s[1], " examined ", s[2],
            " invalidation events ", s[4], " lowered ", s[5])
end
old = ccall(:jl_set_membership_walk_invalidates, Cint, (Cint,), 0)
rows = Any[]
w = Base.get_world_counter()
for en in list
    getfield(en, :max_world) == typemax(UInt64) || continue
    S, X = getfield(en, :member), getfield(en, :instance)
    s0 = stat(); t0 = time_ns()
    ccall(:jl_membership_dispatch_walk, Cvoid, (Any, Any, Csize_t), S, X, w)
    t = (time_ns() - t0) / 1e6; s1 = stat()
    push!(rows, (klass(S), origin(S), S, X, t, s1 .- s0))
end
ccall(:jl_set_membership_walk_invalidates, Cint, (Cint,), old)
for k in ("new", "library", "foreign")
    rs = filter(r -> r[1] == k, rows)
    isempty(rs) && continue
    println("R ", rpad(k, 8), " memberships ", lpad(length(rs), 4), " | walk ", round(sum(r[5] for r in rs); digits = 2), " ms",
            " | replayed ", sum(r[6][1] for r in rs), " examined ", sum(r[6][2] for r in rs), " lowered ", sum(r[6][5] for r in rs))
end
println("R all      memberships ", lpad(length(rows), 4), " | walk ", round(sum(r[5] for r in rows); digits = 2), " ms")
println("R the 12 longest:")
for r in first(sort(rows; by = r -> -r[5]), 12)
    println("R   ", rpad(r[1], 8), lpad(round(r[5]; digits = 2), 7), " ms  replayed ", lpad(r[6][1], 4), " examined ", lpad(r[6][2], 5), "  ",
            first(string(r[3]), 70), " in ", first(string(r[4]), 60))
end
println("R by the member's package:")
for o in unique(r[2] for r in rows)
    rs = filter(r -> r[2] == o, rows)
    println("R   ", rpad(o, 28), lpad(length(rs), 4), " memberships ", lpad(round(sum(r[5] for r in rs); digits = 2), 8), " ms")
end
