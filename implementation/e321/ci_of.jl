# E-321: the CodeInstances of a function's specializations after a load: owner, facts (0x20), G2 (0x10), worlds, code.
#   julia --project=<env> ci_of.jl <Module> <function> [<using list>]   (the module found among the loaded ones;
#   CI_SCRIPT=<file> runs a script first)
modname, fname = Symbol(ARGS[1]), Symbol(ARGS[2])
for p in split(get(ARGS, 3, String(modname)), ',')
    @eval using $(Symbol(p))
end
if haskey(ENV, "CI_SCRIPT")    # the script's own arguments: CI_ARGS, space separated
    empty!(ARGS); append!(ARGS, split(get(ENV, "CI_ARGS", "")))
    println("world before the script ", Base.get_world_counter()); include(ENV["CI_SCRIPT"])
end
M = only(m for m in values(Base.loaded_modules) if nameof(m) === modname); f = getfield(M, fname)
println("world ", Base.get_world_counter())
for m in methods(f), mi in Base.specializations(m)
    println(mi.specTypes)
    ci = isdefined(mi, :cache) ? mi.cache : nothing
    while ci !== nothing
        fl = getfield(ci, :flags, :monotonic)::UInt8
        println("   owner=", ci.owner === nothing ? "native" : typeof(ci.owner), " facts=", (fl & 0x20) != 0, " G2=", (fl & 0x10) != 0,
                " flags=", repr(fl), " worlds=", ci.min_world, ":", ci.max_world == typemax(UInt) ? "∞" : ci.max_world,
                " invoke=", ci.invoke != C_NULL, " inferred=", isdefined(ci, :inferred) && ci.inferred !== nothing)
        if haskey(ENV, "CI_EDGES") && (fl & 0x04) == 0 && isdefined(ci, :edges)
            for e in ci.edges
                println("      edge ", first(sprint(show, e), 220))
            end
        end
        ci = isdefined(ci, :next) ? ci.next : nothing
    end
end
if haskey(ENV, "CI_EDGES")   # the methods of ForwardDiff with a generator: their worlds
    for m in Base.methods_including_ambiguous === nothing ? () : ()
    end
end
