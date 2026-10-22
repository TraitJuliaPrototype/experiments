# E-157 check 4: a second ChainModel{G} (a new graph type) and a new plain function compile no
# CodeInstance of the solver's functions under `Dynamic`. Method: every method of ODECore (the
# solvers, the problem, the integrators) and of TraitDifferentialEquations (the front end), from
# Julia's global method table; the CodeInstances of their specializations, counted before and after
# (common.jl, `snapshot`). Every module is counted too, to show what the new model does compile
# (itself, at its signature). SnoopCompileCore's `@snoop_inference` lists what was inferred, by
# module of the method, as a second view. A control at the end: `compiled_for` must compile new
# solver code (the method sees it).
using SnoopCompileCore
include(joinpath(@__DIR__, "common.jl"))
using ChainModels
header("check 4", "no new CodeInstance of the solver's functions for a new model or function (Dynamic)")

const SOLVER = modpred(ODECore, TraitDifferentialEquations)
const ALL = m -> true
"The modules of the methods inferred under `tinf` (SnoopCompileCore's tree), with counts."
function inferred_bymodule(tinf)
    d = Dict{String,Int}(); names = String[]
    walk(n) = for c in n.children
        mi = c.ci.def
        mi isa Core.MethodInstance || (mi = mi.def)
        m = mi.def
        k = m isa Method ? string(m.module) : string(m)
        d[k] = get(d, k, 0) + 1
        k in ("TraitDifferentialEquations.ODECore", "TraitDifferentialEquations") && push!(names, string(m.name, " ", mi.specTypes))
        walk(c)
    end
    walk(tinf)
    return sort!(collect(d); by = first), names
end

const U0 = collect(range(0.0, 1.0; length = 40))
const PV = [1.0, 0.1]
const PNT = (k = 1.0, d = 0.1)
algs() = (Tsit5(), Rodas5(), Rodas5(chunk_size = 0))
function solve_all(f, p)
    for alg in algs()
        solve(ODEProblem(f, U0, (0.0, 1.0), p), alg)
    end
    solve(ODEProblem(f, U0, (0.0, 1.0), p), Tsit5(); saveat = 0.0:0.1:1.0)
    return nothing
end
function step(label, thunk)
    s0 = snapshot(SOLVER); a0 = snapshot(ALL)
    tinf = @snoop_inference thunk()
    s1 = snapshot(SOLVER); a1 = snapshot(ALL)
    println("--- ", label)
    report_new("ODECore + TraitDifferentialEquations (the solver, the problem, the front end)", newin(s0, s1))
    tw = [k for k in newin(a0, a1) if k[1].def.module === TraitWorld]
    report_new("TraitWorld (the machinery of the kept function)", tw; show = 25)
    println("  every module: ", sum(n for (_, n) in bymodule(newin(a0, a1)); init = 0), " new CodeInstance(s), by module of the method: ",
            join(["$k $n" for (k, n) in bymodule(newin(a0, a1))], ", "))
    inf, nm = inferred_bymodule(tinf)
    println("  @snoop_inference, methods inferred, by module: ", isempty(inf) ? "none" : join(["$k $n" for (k, n) in inf], ", "))
    isempty(nm) || println("     of them in the solver's modules: ", join(first.(nm, 200), "\n       "))
    println()
    return length(newin(s0, s1))
end

# the first model: its keys (Vector p, named-tuple p) compile the solver once each
step("warm-up: ChainModel{PathGraph}, Vector p and NamedTuple p (Tsit5, Rodas5, Rodas5 chunk at init, saveat)",
     () -> (solve_all(ChainModel(PathGraph(40)), PV); solve_all(ChainModel(PathGraph(40)), PNT)))
n1 = step("a second graph type: ChainModel{RingGraph}, the same keys", () -> (solve_all(ChainModel(RingGraph(40)), PV); solve_all(ChainModel(RingGraph(40)), PNT)))
n2 = step("a third graph type: ChainModel{EdgeList}", () -> solve_all(ChainModel(EdgeList(40, [(i, i + 1) for i in 1:39])), PV))
decay!(du, u, p, t) = (du .= -p[1] .* u; nothing)
n3 = step("a new plain function (decay!), Vector p", () -> solve_all(decay!, PV))
n4 = step("a closure, NamedTuple p", () -> let c = 0.5; solve_all((du, u, p, t) -> (du .= -c * p.k .* u; nothing), PNT); end)
nc = step("control: compiled_for(ChainModel(RingGraph(40))), Tsit5 only (expected: new solver code)",
          () -> solve(ODEProblem(compiled_for(ChainModel(RingGraph(40))), U0, (0.0, 1.0), PV), Tsit5()))
println("RESULT check4 new solver CodeInstances: RingGraph $n1, EdgeList $n2, decay! $n3, closure $n4; control (compiled_for) $nc")
footer()
