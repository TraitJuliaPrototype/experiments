# E-388: how long is the chain of CodeInstances the runtime walks at an `invoke` (gf.c,
# jl_method_compiled_callptr), and where on it is the code that runs? Over every MethodInstance of the
# modules in ARGS (default Compiler, Base, Core), after the packages in ENV["CHAINS_LOAD"] are loaded
# and, with CHAINS_WORK set, after that file ran.
for p in split(get(ENV, "CHAINS_LOAD", "")); Core.eval(Main, :(using $(Symbol(p)))); end
haskey(ENV, "CHAINS_WORK") && include(ENV["CHAINS_WORK"])
function chain(mi)
    n = 0; at = 0; owned = 0; noinvoke = 0; dead = 0
    w = Base.get_world_counter()
    isdefined(mi, :cache) || return (0, 0, 0, 0, 0)
    ci = mi.cache
    while true
        n += 1
        if ci.owner !== nothing; owned += 1
        elseif !(ci.min_world <= w <= ci.max_world); dead += 1
        elseif ci.invoke == C_NULL; noinvoke += 1
        elseif at == 0; at = n; end
        isdefined(ci, :next) || break
        ci = ci.next
    end
    return (n, at, owned, noinvoke, dead)
end
function allmethods(mod)
    out = Method[]
    Base.visit(Core.methodtable) do m
        Base.moduleroot(m.module) === mod && push!(out, m)
    end
    return out
end
function census(mod)
    lens = Int[]; ats = Int[]; own = 0; noi = 0; dead = 0
    for m in allmethods(mod)
        for mi in Base.specializations(m)
            n, at, o, ni, d = chain(mi)
            n == 0 && continue
            push!(lens, n); at > 0 && push!(ats, at); own += o; noi += ni; dead += d
        end
    end
    isempty(lens) && return println(mod, ": none")
    q(v, p) = sort(v)[max(1, ceil(Int, p * length(v)))]
    println(mod, ": ", length(lens), " instances with code | chain length mean ", round(sum(lens) / length(lens); digits = 2), ", 90 % ", q(lens, 0.9), ", 99 % ", q(lens, 0.99), ", max ", maximum(lens),
            " | the code that runs is at position: mean ", isempty(ats) ? "-" : round(sum(ats) / length(ats); digits = 2), ", 99 % ", isempty(ats) ? "-" : q(ats, 0.99), ", max ", isempty(ats) ? "-" : maximum(ats),
            " | on the chains: ", own, " of another owner, ", noi, " without code, ", dead, " ended")
end
for a in (isempty(ARGS) ? ["Compiler", "Base", "Core"] : ARGS)
    census(a == "Compiler" ? Base.Compiler : getfield(Main, Symbol(a)))
end
