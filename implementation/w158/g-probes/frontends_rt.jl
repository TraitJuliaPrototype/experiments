# Open issue 250: nl_with_problem at sys::Any, its result as each interpreter gives it, unoptimized and optimized.
# Run: $JN --project=$ENVG $W158/g-probes/frontends_rt.jl
include(joinpath(@__DIR__, "frontends.jl"))
const CC = TraitWorld.CC
w = Base.get_world_counter()
tt = (TNS.NLCoreSolution{Float64}, typeof(nlp), Any)
for facts in (false, true), opt in (false, true)
    interp = CC.NativeInterpreter(w; facts)
    for (src, rt) in Base.code_typed(TNS.nl_with_problem, tt; optimize = opt, interp)
        println("\n== facts = $facts, optimize = $opt: the result ", rt)
        for (i, st) in enumerate(src.code)
            println("     %", i, " = ", st, " :: ", src.ssavaluetypes[i])
        end
        println("   effects: ", src isa Core.CodeInfo ? "" : "")
    end
end
mi = Base.method_instance(TNS.nl_with_problem, tt)
println("\nthe instance: ", mi)
for ci in (isdefined(mi, :cache) ? [mi.cache] : [])
    c = ci
    while c !== nothing
        println("   CodeInstance: rettype ", c.rettype, ", facts flag ", TraitWorld.CC.ci_policy_facts(c), ", worlds ", c.min_world, ":", c.max_world)
        c = isdefined(c, :next) ? c.next : nothing
    end
end
