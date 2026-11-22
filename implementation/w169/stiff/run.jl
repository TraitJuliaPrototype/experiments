# E-537 (W-169): the steady state of a stiff problem, one stack per process.
#     julia run.jl <stack> <problem> <cb> <form> [mode]
#   stack:   port (the ODE port, TraitDifferentialEquations) | plain (the twin PlainODE) | up (upstream OrdinaryDiffEq)
#   problem: bruss (2-D Brusselator, BRUSS_N) | pollu (POLLU, 20 states)
#   cb:      0 | 1 (a periodic pulse, a DiscreteCallback, problems.jl)
#   form:    the right-hand side's form. port: box (the default: `Callable` erases) | compiled (`compiled_for(f)`);
#            plain: wrap (PlainODE's default: FunctionWrappers) | spec (the function itself, `SpecAD` below: the
#            plain form of `compiled_for`, written here since PlainODE's Rodas5 has none);
#            up: auto (SciML's default AutoSpecialize) | full (`FullSpecialize`)
#   mode:    time (default: 2 warm-up solves, then NT = 7 timed solves) | profile (PROF_S seconds of solves under the
#            sampling profiler with C frames, then the samples classed, profclass.jl) | ref (one solve at
#            abstol = reltol = 1e-12, printed as the reference)
# Every solve: Rodas5, abstol 1e-8, reltol 1e-6 (TOL_A, TOL_R), saveat 11 points, the Jacobian by ForwardDiff's duals
# in chunks of 8, dense LU (LAPACK's getrf, one BLAS thread).
const STACK, PROB, CB, FORM = ARGS[1], ARGS[2], ARGS[3] == "1", ARGS[4]
const MODE = length(ARGS) >= 5 ? ARGS[5] : "time"
const HERE = @__DIR__
include(joinpath(HERE, "problems.jl"))
using LinearAlgebra, Profile
include(joinpath(HERE, "profclass.jl"))
LinearAlgebra.BLAS.set_num_threads(1)
const TOLA = parse(Float64, get(ENV, "TOL_A", "1e-8"))
const TOLR = parse(Float64, get(ENV, "TOL_R", "1e-6"))

@static if STACK == "port"
    using TraitWorld, TraitDifferentialEquations
    const ODE = TraitDifferentialEquations
    function mkprob(f, u0, tspan, p)
        FORM == "box" ? ODE.ODEProblem(f, u0, tspan, p) :
        FORM == "compiled" ? ODE.ODEProblem(compiled_for(f), u0, tspan, p) : error("port form: box or compiled")
    end
    mkalg() = ODE.Rodas5()
    dosolve(prob, cbs, tola, tolr, saveat) = cbs === nothing ?
        ODE.solve(prob, ALG; abstol = tola, reltol = tolr, saveat = saveat) :
        ODE.solve(prob, ALG; abstol = tola, reltol = tolr, saveat = saveat, callback = cbs)
    mkcb(c, a) = ODE.DiscreteCallback(c, a)
    counts(s, n) = (naccept = s.naccept, nreject = s.nreject, nf = s.nf, njac = s.naccept + s.nreject,
                    nw = s.naccept + s.nreject, jaccalls = (s.naccept + s.nreject) * cld(n, 8))
    lastu(s) = s.u[end]
elseif STACK == "plain"
    using PlainODE
    const ForwardDiff = PlainODE.ForwardDiff      # the twin's own ForwardDiff (not a direct dependency of the environment)
    # the plain form of `compiled_for` for Rodas5: the function itself in the solver's `m`, the Jacobian by the
    # same duals as PlainODE's `WrappedAD` (its `pjacobian!`, the same loop), so the solver is compiled for `f`.
    # 20 lines outside the tree; PlainODE's own Rodas5 always wraps the function.
    struct SpecAD{F,N}
        f::F
    end
    (m::SpecAD)(du, u, p, t) = (m.f(du, u, p, t); nothing)
    function PlainODE.pjacobian!(m::SpecAD{F,N}, J::Matrix{Float64}, u::Vector{Float64}, p, t::Float64) where {F,N}
        n = length(u)
        ud = Vector{PlainODE.FDual{N}}(undef, n)
        dd = Vector{PlainODE.FDual{N}}(undef, n)
        for c0 in 1:N:n
            for j in 1:n
                ud[j] = PlainODE.FDual{N}(u[j], ForwardDiff.Partials(ntuple(k -> j == c0 + k - 1 ? 1.0 : 0.0, Val(N))))
            end
            m.f(dd, ud, p, t)
            for k in 1:N
                col = c0 + k - 1
                col > n && break
                for i in 1:n
                    J[i, col] = ForwardDiff.partials(dd[i], k)
                end
            end
        end
        return nothing
    end
    mkprob(f, u0, tspan, p) = PlainODE.ODEProblem(f, u0, tspan, p)
    mkalg() = PlainODE.Rodas5()
    function dosolve(prob, cbs, tola, tolr, saveat)
        if FORM == "wrap"
            return cbs === nothing ? PlainODE.solve(prob, ALG; abstol = tola, reltol = tolr, saveat = saveat) :
                   PlainODE.solve(prob, ALG; abstol = tola, reltol = tolr, saveat = saveat, callback = cbs)
        elseif FORM == "spec"
            opts = PlainODE._options(; abstol = tola, reltol = tolr, saveat = saveat)
            return PlainODE.solve_ode(SpecAD{typeof(prob.f),min(length(prob.u0), 8)}(prob.f), prob.u0, prob.tspan,
                                      ALG, prob.p, PlainODE._kept(cbs), opts)
        else
            error("plain form: wrap or spec")
        end
    end
    mkcb(c, a) = PlainODE.DiscreteCallback(c, a)
    counts(s, n) = (naccept = s.naccept, nreject = s.nreject, nf = s.nf, njac = s.naccept + s.nreject,
                    nw = s.naccept + s.nreject, jaccalls = (s.naccept + s.nreject) * cld(n, 8))
    lastu(s) = s.u[end]
elseif STACK == "up"
    using OrdinaryDiffEqRosenbrock, SciMLBase, ADTypes, LinearSolve
    mkprob(f, u0, tspan, p) = FORM == "auto" ? ODEProblem(f, u0, tspan, p) :
                              FORM == "full" ? ODEProblem{true,SciMLBase.FullSpecialize}(f, u0, tspan, p) :
                              error("up form: auto or full")
    mkalg() = Rodas5(autodiff = AutoForwardDiff(chunksize = 8), linsolve = LUFactorization())
    dosolve(prob, cbs, tola, tolr, saveat) = cbs === nothing ?
        solve(prob, ALG; abstol = tola, reltol = tolr, saveat = saveat) :
        solve(prob, ALG; abstol = tola, reltol = tolr, saveat = saveat, callback = cbs)
    mkcb(c, a) = DiscreteCallback(c, a)
    counts(s, n) = (naccept = s.stats.naccept, nreject = s.stats.nreject, nf = s.stats.nf, njac = s.stats.njacs,
                    nw = s.stats.nw, jaccalls = -1)
    lastu(s) = s.u[end]
else
    error("stack: port, plain or up")
end

const ALG = mkalg()
const F, U0, TSPAN, P, COND, AFF, T1 = problem(PROB)
const SAVEAT = collect(range(TSPAN[1], TSPAN[2]; length = 11))
const PRB = mkprob(F, U0, TSPAN, P)
const CBS = CB ? mkcb(COND, AFF) : nothing
one_solve(tola = TOLA, tolr = TOLR) = (reset_pulse!(T1); dosolve(PRB, CBS, tola, tolr, SAVEAT))
tag() = "$STACK $PROB cb$(Int(CB)) $FORM n=$(length(U0))"

function readref()
    f = joinpath(HERE, "refs", "$PROB-cb$(Int(CB)).txt")
    isfile(f) || return nothing
    return parse.(Float64, split(strip(read(f, String))))
end
relerr(u, r) = r === nothing ? NaN : maximum(abs.(u .- r)) / maximum(abs.(r))

if MODE == "ref"
    s = one_solve(1e-12, 1e-12)
    println(join(repr.(lastu(s)), " "))
    println(stderr, "REF ", tag(), " ", counts(s, length(U0)), " pulses ", PULSES[])
elseif MODE == "time"
    NT = parse(Int, get(ENV, "NT", "7"))
    s = one_solve(); s = one_solve()                       # two warm-up solves
    ts = Float64[]; bs = Int[]; gs = Float64[]
    for k in 1:NT
        GC.gc(false)
        r = @timed one_solve()
        push!(ts, r.time * 1e3); push!(bs, r.bytes); push!(gs, r.gctime * 1e3)
        global s = r.value
        println("S ", tag(), " solve $k ", round(r.time * 1e3; digits = 3), " ms ", r.bytes, " bytes gc ", round(r.gctime * 1e3; digits = 3), " ms")
    end
    c = counts(s, length(U0))
    st = sort(ts)
    med = isodd(NT) ? st[(NT + 1) ÷ 2] : (st[NT ÷ 2] + st[NT ÷ 2 + 1]) / 2
    println("R ", tag(), " | min ", round(st[1]; digits = 3), " med ", round(med; digits = 3), " ms | alloc ",
            round(sum(bs) / NT / 2^20; digits = 3), " MiB gc ", round(sum(gs) / NT; digits = 3), " ms per solve | naccept ",
            c.naccept, " nreject ", c.nreject, " nf ", c.nf, " njac ", c.njac, " nw ", c.nw, " jaccalls ", c.jaccalls,
            " | pulses ", PULSES[], " | err ", round(relerr(lastu(s), readref()); sigdigits = 3), " | ", s.retcode)
elseif MODE == "profile"
    one_solve(); one_solve()
    secs = parse(Float64, get(ENV, "PROF_S", "8"))
    Profile.init(n = 10^7, delay = 0.0005)
    t0 = time(); nsol = 0
    Profile.@profile while time() - t0 < secs
        one_solve(); global nsol += 1
    end
    println("P ", tag(), " solves ", nsol, " in ", round(time() - t0; digits = 2), " s")
    profclass(stdout, "P " * tag(), nsol)
else
    error("mode: time, profile or ref")
end
