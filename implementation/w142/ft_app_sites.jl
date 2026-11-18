# W-142: the sites of the session's check of a program, each with the instance that holds it and the
# first instance of the user's code above it: julia --project=<env> ft_app_sites.jl <app.jl>
Base.include(Main, abspath(ARGS[1]))
const CC = Base.Compiler
sig = Tuple{typeof(main), Vector{String}}
world = Base.get_world_counter()
mi = CC.specialize_method(only(Base._methods_by_ftype(sig, 1, world)))
errors, parents = CC.closed_check(Any[mi], world)
for (warn, e) in errors
    warn && continue
    chain = Any[]
    ci = e.codeinst
    while true
        push!(chain, CC.get_ci_mi(ci))
        haskey(parents, ci) || break
        ci = parents[ci][1]
    end
    println(e.desc, " | in ", chain[1].specTypes)
    for m in chain[2:end]
        mod = m.def isa Method ? m.def.module : m.def
        Base.moduleroot(mod) in (Base, Core) && continue
        println("      <- ", m.specTypes); break
    end
end
if get(ENV, "JULIA_CLOSED_BUILD_REPORT", "") != ""
end
exit(0)
