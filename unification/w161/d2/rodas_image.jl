# W-161, E-501: is `TraitRodas._rodas5_run` at the ODE session's problem type in the package image, valid at load?
# The session compiles it on the head (315 ms, `logs/ode-head.trace`), not on the baseline.
#     julia --project=<env> rodas_image.jl
using TraitWorld, TraitDifferentialEquations
const TR = TraitDifferentialEquations.TraitRodas
for m in methods(TR._rodas5_run)
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        valid = false
        while ci !== nothing
            ci.max_world == typemax(UInt) && (valid = true)
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
        println(valid ? "valid  " : "no code", "  ", mi.specTypes)
    end
end
