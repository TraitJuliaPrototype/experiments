# Open issue 250: the front ends with a declared result at the two constructors that take `sys::Any`, redefined in
# this session only (the port's files are not changed). Run: $JN --project=$ENVG $W158/g-probes/frontends_fix.jl
include(joinpath(@__DIR__, "frontends.jl"))
@eval TNS nl_with_problem(s::NLCoreSolution{T}, prob::NonlinearProblemTrait{T,P}, @nospecialize(sys)) where {T,P} =
    NonlinearSolution{T,P}(s.u, s.resid, s.retcode, s.stats, prob, sys)::NonlinearSolution{T,P}
@eval OC with_problem(s::CoreSolution{T}, prob::ODEProblemTrait{T,P}, sys, names, pt::Vector{Float64}, pu::Vector{P}) where {T,P} =
    $(Expr(:(::), :(ODESolution{T,P}(s.t, s.u, s.retcode, s.naccept, s.nreject, s.nf, prob, sys, names, pt, pu, s.interp)), :(ODESolution{T,P})))
println("\nwith the declared results:")
for (name, f, tt) in cases
    println("   ", rpad(name, 28), Base.infer_return_type(f, tt))
end
if get(ENV, "RUN", "0") == "1"
    a = ODE.solve(nlp, nr); b = ODE.solve(odp, ts; reltol = 1e-6, abstol = 1e-8)
    println("ran: ", a.retcode, " ", b.retcode)
end
