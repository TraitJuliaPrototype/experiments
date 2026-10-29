# E-229, W-34's move 5 (writeup/plans/2026-10-29-sciml-finish.md §4, checks 3–6): the solution keeps its problem
# as a kept value; one solution type per state and parameter type; DiffEqArray conforms; a helper over
# trajectories (TraitArrayTools.plotpoints) is compiled once per solution type, once for Dynamic{Trajectory}.
# Check 6 runs before check 5, which calls plotpoints too. Counting CodeInstances: every method of TraitArrayTools from Julia's global method table, the CodeInstances in
# each specialization's cache by owner (plain, facts, TraitWorld's check owner), before and after each step.
using TraitWorld, TraitDifferentialEquations, TraitArrayTools, ChainModels, LorenzModels
const ODECore = TraitDifferentialEquations.ODECore

gitc(d) = let c = try readchomp(`git -C $d rev-parse --short HEAD`) catch; "?" end
    dirty = try !isempty(readchomp(`git -C $d status --porcelain --untracked-files=no`)) catch; false end
    dirty ? c * "+changes" : c
end
loadavg() = join(first(split(read("/proc/loadavg", String)), 3), " ")
println("== E-229: move 5, the solution as a trajectory")
println("   julia-1.13 ", gitc(joinpath(dirname(pkgdir(TraitWorld)), "julia-1.13")), " (prints ", Base.GIT_VERSION_INFO.commit_short, ")  TraitWorld ", gitc(pkgdir(TraitWorld)), "  TDE ", gitc(pkgdir(TraitDifferentialEquations)),
        " (", readchomp(`git -C $(pkgdir(TraitDifferentialEquations)) branch --show-current`), ")  setting ",
        Base.Compiler.NativeInterpreter().facts ? "all" : "product", "  strict ", TraitWorld.STRICT[] ? "on" : "off")
println("   load at start: ", loadavg(), "\n")

const MT = isdefined(Core, :methodtable) ? Core.methodtable : Core.GlobalMethods
function snapshot(mod)
    snap = Dict{Tuple{Core.MethodInstance,Any},Int}()
    Base.visit(MT) do m
        m.module === mod || return
        for mi in Base.specializations(m)
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci !== nothing
                k = (mi, ci.owner); snap[k] = get(snap, k, 0) + 1
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
    return snap
end
newin(a, b) = [k for (k, n) in b if get(a, k, 0) < n]
ownername(o) = o === nothing ? "plain" : o === :facts ? "facts" : "check"
fails = 0
check(label, ok) = (println(ok ? "  pass  " : "  FAIL  ", label); ok || (global fails += 1))

lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
const U0 = [1.0, 0.0, 0.0]; const P0 = [10.0, 28.0, 8 / 3]; const U40 = collect(range(0.0, 1.0; length = 40))

println("check 3: one solution type per state and parameter type")
sols = Pair{String,Any}[
    "a function, Tsit5" => solve(ODEProblem(lorenz!, U0, (0.0, 1.0), P0), Tsit5()),
    "the function compiled_for, Tsit5" => solve(ODEProblem(compiled_for(lorenz!), U0, (0.0, 1.0), P0), Tsit5()),
    "a callable model ChainModel{PathGraph}, Tsit5" => solve(ODEProblem(ChainModel(PathGraph(40)), U40, (0.0, 1.0), [1.0, 0.1]), Tsit5()),
    "a callable model ChainModel{RingGraph}, Rodas5" => solve(ODEProblem(ChainModel(RingGraph(40)), U40, (0.0, 1.0), [1.0, 0.1]), Rodas5()),
    "a function, Rodas5 with the chunk at init" => solve(ODEProblem(lorenz!, U0, (0.0, 1.0), P0), Rodas5(chunk_size = 0)),
    "a problem type LorenzProblem, Rodas5" => solve(LorenzProblem(copy(U0), (0.0, 1.0), 10.0, 28.0, 8 / 3), Rodas5()),
    "a function, Tuple parameters" => solve(ODEProblem(lorenz!, U0, (0.0, 1.0), (10.0, 28.0, 8 / 3)), Tsit5()),
    "a Float32 state" => solve(ODEProblem(lorenz!, Float32.(U0), (0.0, 1.0), Float32.(P0)), Tsit5()),
]
for (l, s) in sols
    println("  ", rpad(l, 50), typeof(s), "   sol.prob: ", typeof(s.prob))
end
check("the first five (functions, compiled, callable models, Tsit5, Rodas5) have one type, ODESolution{Float64, Vector{Float64}}",
      all(typeof(last(p)) === ODESolution{Float64,Vector{Float64}} for p in sols[1:5]))

println("\ncheck 4: sol.prob, the problem kept")
for (l, s, p, u0) in (("a function", sols[1][2], P0, U0), ("a problem type", sols[6][2], nothing, U0))
    pr = s.prob
    du = zeros(3); rhs!(pr, du, u0, 0.0)
    du0 = zeros(3); lorenz!(du0, u0, P0, 0.0)
    check("$l: u0, tspan read back; rhs!(sol.prob, …) is the problem's derivative", pr.u0 == u0 && pr.tspan == (0.0, 1.0) && du == du0)
end
check("a function: sol.prob.p is the problem's p", sols[1][2].prob.p == P0)
check("a problem type: sol.prob.p is its LorenzParams", sols[6][2].prob.p isa LorenzParams{Float64})

println("\ncheck 6: plotpoints compiled once per solution type, once for Dynamic{Trajectory}")
s1 = sols[1][2]
a = DiffEqArray(s1.u, s1.t)        # a trajectory from anywhere: the first solution's states
plot_typed(s) = plotpoints(s, 1)                     # a typed caller: the solution is seen at its type
prev = snapshot(TraitArrayTools)
steps = Pair{String,Any}[(l => s) for (l, s) in sols]
push!(steps, "a DiffEqArray{Float64}" => a)
for (l, s) in steps
    plot_typed(s)
    now_ = snapshot(TraitArrayTools); ks = newin(prev, now_)
    println("  typed, ", rpad(l, 52), lpad(length(ks), 3), " new CodeInstance(s) in TraitArrayTools  ",
            join(sort!(unique(string(ownername(o)) for (mi, o) in ks)), ","))
    global prev = now_
end
plot_dyn(d) = plotpoints(d, 1)
for (l, s) in steps[[1, 3, 6, 7, 9]]
    eltype(s.u[1]) === Float64 || continue
    plot_dyn(Dynamic{Trajectory{Vector{Float64},Float64}}(s))
    now_ = snapshot(TraitArrayTools); ks = newin(prev, now_)
    println("  Dynamic{Trajectory{Vector{Float64}, Float64}}, ", rpad(l, 32), lpad(length(ks), 3), " new CodeInstance(s)")
    global prev = now_
end
println("\nThe specializations of plotpoints and the trait's operations at the end (MethodInstance, owner):")
for ((mi, o), n) in sort!(collect(prev); by = x -> string(x[1][1].def.name, x[1][1].specTypes))
    mi.def.name in (:plotpoints, :times, :state, :at) || continue
    s = string(mi.specTypes)
    println("  [", ownername(o), "] ", mi.def.name, "  ", length(s) > 200 ? s[1:200] * "…" : s)
end
println("\ncheck 5: DiffEqArray conforms; the same points")
check("plotpoints(sol, i) == plotpoints(DiffEqArray(sol.u, sol.t), i), i = 1:3", all(plotpoints(s1, i) == plotpoints(a, i) for i in 1:3))
check("at agrees inside the span: a(τ) == sol(τ)", all(a(τ) == s1(τ) for τ in 0.0:0.05:1.0))

println("\nchecks failed: ", fails)
println("load at end: ", loadavg())
