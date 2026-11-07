# E-279: the plain code that facts code rests on (compiler §2.2: which of Base's methods carry the
# boundary flag is a choice of the setting, made by measurement). A workload runs inside a module
# compiled by facts; of the facts CodeInstances it makes, count those holding an edge to a plain
# callee (a code edge to its CodeInstance, or a dispatch edge at a method whose policy is plain),
# and list the callees' methods by the number of facts callers resting on them. A plain callee whose
# own record satisfies G2 is stable under loads as facts code is; the count of facts code resting on
# plain code that does not ("exposed") is the one a boundary would lower.
# Usage: julia --project=TraitWorld-unified boundaries.jl <workload.jl>
const G2, FACTS = 0x10, 0x20
function native_cis()
    s = IdSet{Any}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci !== nothing
                ci.owner === nothing && push!(s, ci)
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
    return s
end
policy(m::Method) = ccall(:jl_method_policy, Cint, (Any,), m)   # 0 plain, 1 facts, 2 caller's
before = native_cis()
@eval module Work
Base.Experimental.@compiler_options facts=true
include($(abspath(ARGS[1])))
end
after = native_cis()
nfacts = 0; nrest = 0; nexposed = 0
callers = Dict{Method,Int}(); exposed = Dict{Method,Int}()
# the plain CodeInstance of a method instance now, if any
function plain_ci(mi::Core.MethodInstance)
    ci = isdefined(mi, :cache) ? mi.cache : nothing
    while ci !== nothing
        ci.owner === nothing && (ci.flags & FACTS) == 0 && ci.max_world == typemax(UInt) && return ci
        ci = isdefined(ci, :next) ? ci.next : nothing
    end
    return nothing
end
for ci in after
    ci in before && continue
    (ci.flags & FACTS) != 0 || continue
    global nfacts += 1
    rests = Set{Method}(); unstable = Set{Method}()
    for e in ci.edges
        if e isa Core.CodeInstance
            if (e.flags & FACTS) == 0 && e.def.def isa Method
                push!(rests, e.def.def)
                (e.flags & G2) == 0 && push!(unstable, e.def.def)
            end
        elseif e isa Core.MethodInstance && e.def isa Method
            if policy(e.def) == 0
                push!(rests, e.def)
                pc = plain_ci(e)
                (pc === nothing || (pc.flags & G2) == 0) && push!(unstable, e.def)
            end
        end
    end
    isempty(rests) && continue
    global nrest += 1
    for m in rests
        callers[m] = get(callers, m, 0) + 1
    end
    isempty(unstable) && continue
    global nexposed += 1
    for m in unstable
        exposed[m] = get(exposed, m, 0) + 1
    end
end
println("facts CodeInstances made by the workload: $nfacts; resting on plain code: $nrest (",
        nfacts == 0 ? "—" : string(round(100nrest / nfacts; digits = 1)), " %)")
println("resting on plain code that misses G2 (exposed): $nexposed (",
        nfacts == 0 ? "—" : string(round(100nexposed / nfacts; digits = 1)), " %)")
println("the plain methods missing G2 that facts code rests on:")
for (m, n) in sort!(collect(exposed); by = last, rev = true)
    println("  ", lpad(n, 5), "  ", m.module, ".", m.name, "  ", m.sig)
end
bymod = Dict{Module,Int}()
for (m, n) in callers
    r = Base.moduleroot(m.module)
    bymod[r] = get(bymod, r, 0) + n
end
println("callers' edges into plain code, by the callee's root module: ",
        join(["$k $v" for (k, v) in sort!(collect(bymod); by = last, rev = true)], ", "))
println("the 25 plain methods most rested on:")
for (m, n) in first(sort!(collect(callers); by = last, rev = true), 25)
    println("  ", lpad(n, 5), "  ", m.module, ".", m.name, "  ", m.sig)
end
