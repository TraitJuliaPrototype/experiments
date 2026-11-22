# E-537 §4: NetworkDynamics' steady state, step d of the workload's `again` pass (ndport/scripts/workload_steps.jl:
# the swing network with its line-trip callbacks, a Tsit5 solve and a stiff solve), told apart: each solve timed
# alone, its steps, right-hand-side calls and Jacobians counted, its allocations; then each profiled.
#     cd ndport; NDW_STACK=ports NDW_API=ports julia --project=<nd env> nd_steady.jl [time|profile]
# NDW_STACK=ports: the port on TraitDifferentialEquations; else upstream's packages (SciML). NDW_API=ports: Rodas5 and
# saveat = TIMES on both (the port's variant, the workload's U′); NDW_API=upstream: Rodas5P, no saveat (E-514's V run).
# The plotting steps f and g are not loaded.
const MODE = length(ARGS) >= 1 ? ARGS[1] : "time"
const ON_PORTS = get(ENV, "NDW_STACK", "upstream") == "ports"
const HERE = @__DIR__
const ND = joinpath(HERE, "..", "..", "..", "..", "ndport", "scripts")
using Graphs, NetworkDynamics
if ON_PORTS
    @eval using TraitDifferentialEquations, SymbolicIndexingInterface
else
    @eval using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, DiffEqCallbacks, SymbolicIndexingInterface
end
include(joinpath(ND, "workload_steps.jl"))
using Profile
include(joinpath(HERE, "profclass.jl"))
using LinearAlgebra
LinearAlgebra.BLAS.set_num_threads(1)
# the right-hand side: NetworkDynamics' core loop and the user's component functions; callbacks: NetworkDynamics'
# component callbacks and the solvers' event handling
RHS_FRAME[] = fr -> (b = basename(String(fr.file)); b in ("coreloop.jl", "aggregators.jl", "gbufs.jl") ||
                     String(fr.func) in ("swing!", "line!"))
CB_FRAME[] = fr -> (b = basename(String(fr.file)); n = String(fr.func);
                    (b == "callbacks.jl" && occursin("NetworkDynamics", String(fr.file))) ||
                    occursin(r"^(handle_callbacks!|find_first_continuous_callback|find_callback_time|apply_callback!|find_root|bisection|locate_events!|step_event_condition|event_affect_dir!|step_condition|step_affect!|_condition|apply_discrete_callback!|find_first_ilsp|determine_event_occurance|get_condition)$", n))

@noinline one_solve(f) = f()             # the profile's root: the samples inside a solve
CB_FIRST[] = true
stats(s) = hasproperty(s, :stats) ?
    (naccept = s.stats.naccept, nreject = s.stats.nreject, nf = s.stats.nf, njac = s.stats.njacs, nw = s.stats.nw) :
    (naccept = s.naccept, nreject = s.nreject, nf = s.nf, njac = -1, nw = -1)

Base.invokelatest() do
    a = NDW.step_a(:swing); nw = NDW.step_b(a); c = NDW.step_c(nw)
    r = NDW.step_d(nw, c.s); r = NDW.step_d(nw, c.s)                 # the first pass and `again`
    prob = r.prob
    fresh() = remake(prob; p = copy(prob.p))
    tsit() = solve(fresh(), Tsit5(); NDW.SOLVE_KW..., NDW.SAVE_KW...)
    stiff() = solve(fresh(), NDW.STIFF(); NDW.SOLVE_KW..., NDW.SAVE_KW...)
    stack = (ON_PORTS ? "port" : "upstream") * " api=" * NDW.API
    n = length(prob.u0)
    if MODE == "time"
        NT = parse(Int, get(ENV, "NT", "7"))
        for (name, f) in (("tsit5", tsit), ("stiff", stiff), ("step_d", () -> NDW.step_d(nw, c.s)))
            f(); f()
            ts = Float64[]; bs = Int[]; gs = Float64[]; local s
            for k in 1:NT
                GC.gc(false)
                t = @timed f()
                push!(ts, t.time * 1e3); push!(bs, t.bytes); push!(gs, t.gctime * 1e3); s = t.value
            end
            st = sort(ts)
            cnt = name == "step_d" ? "trips $(length(s.ttrips)) $(length(s.rtrips)) | tsit5 $(stats(s.sol)) | stiff $(stats(s.rsol))" :
                  "$(stats(s)) | saved $(length(s.t)) | retcode $(s.retcode)"
            println("R nd $stack $name n=$n | min ", round(st[1]; digits = 3), " med ", round(st[(NT + 1) ÷ 2]; digits = 3),
                    " ms | alloc ", round(sum(bs) / NT / 2^20; digits = 3), " MiB gc ", round(sum(gs) / NT; digits = 3),
                    " ms per call | ", cnt)
        end
    elseif MODE == "chains"
        # the stacks of the Tsit5 solve's samples that read a declared field at run time, the first 10 Julia frames
        Profile.init(n = 10^7, delay = 0.0005)
        t0 = time(); k = 0
        Base.invokelatest() do
            Profile.@profile while time() - t0 < 5
                one_solve(tsit); k += 1
            end
        end
        data = Profile.fetch(include_meta = false)
        samples = Vector{Vector{Base.StackTraces.StackFrame}}(); cur = Base.StackTraces.StackFrame[]
        for ip in data
            if ip == 0; isempty(cur) || push!(samples, cur); cur = Base.StackTraces.StackFrame[]; else append!(cur, frames(ip)); end
        end
        samples = filter(s -> any(f -> String(f.func) == "one_solve", s), samples)
        sel = filter(s -> any(f -> String(f.func) in ("declared_field_in", "declared_field_type", "_dynamic_field_type"), s), samples)
        println("C nd $stack tsit5: the samples under a declared field's type computed at run time: ", length(sel), " of ", length(samples),
                " (", round(100length(sel) / length(samples); digits = 1), " %)")
        chains = Dict{String,Int}()
        for s in sel
            js = filter(f -> !f.from_c && !(String(f.func) in ("declared_field_in", "declared_field_type", "getindex", "has_free_typevars")), s)
            c = join(["$(f.func) $(basename(String(f.file))):$(f.line)" for f in js][1:min(7, end)], " < ")
            chains[c] = get(chains, c, 0) + 1
        end
        for (c, n) in first(sort(collect(chains); by = kv -> -kv[2]), 10)
            println("C   ", lpad(n, 5), "  ", c)
        end
    else
        secs = parse(Float64, get(ENV, "PROF_S", "8"))
        Profile.init(n = 10^7, delay = 0.0005)
        for (name, f) in (("tsit5", tsit), ("stiff", stiff))
            Profile.clear()
            t0 = time(); k = 0
            Base.invokelatest() do
                Profile.@profile while time() - t0 < secs
                    one_solve(f); k += 1
                end
            end
            println("P nd $stack $name solves $k in ", round(time() - t0; digits = 2), " s")
            profclass(stdout, "P nd $stack $name", k)
        end
    end
end
