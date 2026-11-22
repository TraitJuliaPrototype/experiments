# W-159 probe (open issue 228): right after loading, for each instance of TraitRodas._rodas5_run and of the ODECore
# functions the ODE session compiles (_problem_of, _problem), how many code instances it has, and of them how many
# are valid (max_world typemax) and how many were invalidated (max_world below the load's world). "no code instance"
# = never compiled into the image (missing at load); "invalidated" = kept in the image and dropped at load.
#     julia --project=<env> rodas_ci.jl
using TraitWorld, TraitDifferentialEquations
const T = TraitDifferentialEquations
w = Base.get_world_counter()
for (name, f) in [("_rodas5_run", T.TraitRodas._rodas5_run), ("_problem_of", T.ODECore._problem_of), ("_problem", T.ODECore._problem)]
    for m in methods(f), mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        n = 0; v = 0; inv = 0; ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            n += 1; ci.max_world == typemax(UInt) ? (v += 1) : (inv += 1)
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
        println(rpad(name, 12), " code instances ", n, " valid ", v, " invalidated ", inv, "  ", first(string(mi.specTypes), 230))
    end
end
