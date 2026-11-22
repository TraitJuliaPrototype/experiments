# W-143c (copied from ../w157/diag/culprit.jl; the session by CENSUS_WORK): one culprit of the census up close. For each instance below the own code whose method's name is
# one of ARGS (`Module.name`), outside the deep class: its own faults, a path of callers up to an own
# facts instance, and for a callee named by instance alone, that instance's code now and its bit.
#     CENSUS_WORK=table julia --project=envs/forks diag/culprit.jl <csv> Core.throw_inexacterror Base.Val ...
include(joinpath(@__DIR__, "..", "census_lib.jl"))
const csv = ARGS[1]; const want = Set(ARGS[2:end])
S = census_session(csv)
for (y, k) in S.culprit
    mname(y) in want || continue
    println("== ", k, "  ", first(string(y.def.specTypes), 200), "  (in ", get(S.incone, y, 0), " cones)")
    for f in S.fcache[y]
        println("   fault ", f.kind, ": ", first(string(f.sig), 200))
        if f.kind === :mi
            for c in micode(f.sig); println("      its code: bit ", bit(c), ", facts ", isfacts(c), ", rettype ", c.rettype); end
        end
    end
    # a path of callers up to an own facts instance (breadth first over the reverse edges)
    prev = IdDict{Any,Any}(y => nothing); q = Any[y]; hit = nothing
    while !isempty(q) && hit === nothing
        x = popfirst!(q)
        for p in get(S.rev, x, Any[])
            haskey(prev, p) && continue
            prev[p] = x; push!(q, p)
            if p in S.ownset && isfacts(p); hit = p; break; end
        end
    end
    p = hit; n = 0
    while p !== nothing && n < 12
        println("   <- ", bit(p) ? "[bit] " : "", first(string(p.def.specTypes), 180)); p = prev[p]; n += 1
    end
    println("   direct callers: ", length(get(S.rev, y, Any[])))
    for p in get(S.rev, y, Any[])[1:min(end, 6)]; println("      ", first(string(p.def.specTypes), 160)); end
end
