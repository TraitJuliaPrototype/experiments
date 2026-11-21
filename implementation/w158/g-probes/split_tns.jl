# Open issue 249, the two cases of TraitNonlinearSolve (TDE 1425aec), written beside the port at 3a1c4c3 (the port
# is not changed). Run: $JN --project=$ENVG $W158/g-probes/split_tns.jl
using TraitWorld, TraitDifferentialEquations
const TraitNonlinearSolve = TraitDifferentialEquations.TraitNonlinearSolve
const ODECore = TraitDifferentialEquations.ODECore
println("TraitWorld at ", pathof(TraitWorld))
const TNS = TraitNonlinearSolve

module P
using TraitWorld
using ..TraitNonlinearSolve, ..ODECore
const TNS = TraitNonlinearSolve
# the operation as it was at 1425aec: the solution's element type not named
@trait OldAlg begin
    solve_nl_old(a::OldAlg, m::NLCoreProblem, opts::NLOptions)::NLCoreSolution
end
# case 1 (solve_nonlinear at 1425aec, with the operation's result abstract): nl_with_problem(::NLCoreSolution, box, …)
vA(prob::NonlinearProblemTrait{T,P}, alg::OldAlg, opts::NLOptions) where {T,P} =
    TNS.nl_with_problem(solve_nl_old(alg, TNS.nl_core(prob), opts), prob, ODECore._system(prob))
# case 2 (the front end at 3a1c4c3 without the assertions): the options of keywords the code does not know
vB(prob::NonlinearProblemTrait, alg::NonlinearAlgorithm; abstol = TNS.NL_TOL, reltol = TNS.NL_TOL, maxiters = 1000) =
    TNS.solve_nonlinear(prob, alg, NLOptions(Float64(abstol), Float64(reltol), Int(maxiters)))
# case 2 as it was at 1425aec: the options made by a keyword function
_opts(; abstol = TNS.NL_TOL, reltol = TNS.NL_TOL, maxiters = 1000) = NLOptions(Float64(abstol), Float64(reltol), Int(maxiters))
vB2(prob::NonlinearProblemTrait, alg::NonlinearAlgorithm; kw...) = TNS.solve_nonlinear(prob, alg, _opts(; kw...))
end

fs = Any[P.vA, P.vB, P.vB2, TNS.solve, TNS.solve_nonlinear]
append!(fs, [getglobal(P, n) for n in names(P; all = true) if startswith(string(n), "#vB")])
append!(fs, [getglobal(TNS, n) for n in names(TNS; all = true) if startswith(string(n), "#solve#")])
for f in fs, m in methods(f)
    m.module in (P, TNS) || continue
    sig = TraitWorld.box_signature(m)
    sig === nothing && continue
    fs_ = TraitWorld.check_at_box(m)
    println("\n== ", m.name, " ", m.sig, "\n   faults: ", fs_ === nothing ? "not read" : length(fs_))
    fs_ === nothing || foreach(u -> println("     ", u.kind, ": ", TraitWorld._fault_line(u)), fs_)
    r = Base.code_typed_by_type(sig; optimize = true)
    length(r) == 1 || continue
    src = r[1][1]
    for (i, st) in enumerate(src.code)
        s = sprint(show, st)
        (occursin("throw_methoderror", s) || occursin("(isa)", s) || occursin("unreachable", s) || occursin("typeassert", s)) &&
            println("     %", i, " = ", s, " :: ", src.ssavaluetypes[i])
    end
end
