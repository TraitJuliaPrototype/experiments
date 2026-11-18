# W-161, E-501: which instances of `TraitRodas._rodas5_run` a Rodas5 solve creates in a session, and the
# type of the integrator `rodas5_init` returns (inferred), at a plain function with parameters.
#     julia --project=<env> rodas_probe.jl
using TraitWorld, TraitDifferentialEquations
const TR = TraitDifferentialEquations.TraitRodas
const OC = TraitDifferentialEquations.ODECore
f!(du, u, p, t) = (du .= -p[1] .* u; nothing)
prob = ODEProblem(f!, [1.0, 0.0, 0.0], (0.0, 0.1), [0.5])
println("problem type: ", typeof(prob).name.name, " ", typeof(prob).parameters[3])
s = solve(prob, Rodas5())
for m in methods(TR._rodas5_run), mi in Base.specializations(m)
    mi isa Core.MethodInstance && println("instance: ", mi.specTypes)
end
for m in methods(TR.rodas5_solve), mi in Base.specializations(m)
    mi isa Core.MethodInstance || continue
    println("rodas5_solve instance: ", mi.specTypes)
end
