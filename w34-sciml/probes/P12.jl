# P12: `init` as an operation of the problem trait with a trait-typed result (open issue 51,
# option (d), for the porting guideline): `init(prob::ODEProblemTrait{U, T, P}, alg)::Integrator{U, T, P}`;
# the driver opens the Dynamic result once with `compiled_for`.
# Reference: traits §3.1 (operations; declared result types may name the parameters), §6.2 ("an
# operation's result declared with a trait is Dynamic: its declared type is the trait"; Implemented),
# §6.4 (`compiled_for` opens a Dynamic trait object). Unprobed (plan §1.4).
include("common.jl")
header("P12", "init(prob::ODEProblemTrait{U, T, P}, alg)::Integrator{U, T, P} as an operation; the driver opens the result with compiled_for")

edef = caught(() -> toplevel(quote
    @trait_module module Core1
    using TraitWorld
    @trait Integrator{U, T, P} begin
        @const u::U
        t::T
        @const p::P
        step!(i::Integrator{U, T, P}, dt::T)::Nothing
    end
    @trait ODEProblemTrait{U, T, P} begin
        @const u0::U
        @const tspan::Tuple{T, T}
        @const p::P
        init(prob::ODEProblemTrait{U, T, P}, alg)::Integrator{U, T, P}
    end
    function run!(integ::Integrator{U, T, P}, tf::T, dt::T) where {U, T, P}
        while integ.t < tf
            step!(integ, dt)
        end
        return integ.u[1]
    end
    "The driver: the integrator from the problem's operation, opened once."
    function solve(prob::ODEProblemTrait{U, T, P}, alg) where {U, T, P}
        integ = init(prob, alg)
        t0, tf = prob.tspan
        return run!(compiled_for(integ), tf, (tf - t0) / 4)
    end
    "init's result handed to plain code (a kept value may go up)."
    init_up(prob::ODEProblemTrait{U, T, P}, alg) where {U, T, P} = init(prob, alg)
    "The same without the cast: the Dynamic result at the bound."
    function solve_dyn(prob::ODEProblemTrait{U, T, P}, alg) where {U, T, P}
        integ = init(prob, alg)
        t0, tf = prob.tspan
        return run!(integ, tf, (tf - t0) / 4)
    end
    end
end))
println("trait module: ", errtext(edef))

# the solver package owns the algorithm and the integrator; the problem's package owns the problem
# and implements `init` for it, forwarding to a function solvers extend (SciML's `__init`)
edecl = caught(() -> toplevel(quote
    module SolverPkg
    using TraitWorld
    using ..Core1
    struct Euler end
    mutable struct EulerInteg{U, T, P}; const u::U; t::T; const p::P; const du::U; end
    Core1.step!(i::EulerInteg, dt) = (i.du .= i.p .* i.u; i.u .+= dt .* i.du; i.t += dt; nothing)
    @implement Core1.Integrator EulerInteg{U, T, P} where {U, T, P}
    function __init end
    __init(u0, tspan, p, ::Euler) = EulerInteg(copy(u0), tspan[1], p, similar(u0))
    end
    module ProbPkg
    using TraitWorld
    using ..Core1, ..SolverPkg
    struct Prob{U, T, P}; u0::U; tspan::Tuple{T, T}; p::P; end
    Core1.init(pr::Prob, alg) = SolverPkg.__init(pr.u0, pr.tspan, pr.p, alg)
    @implement Core1.ODEProblemTrait Prob{U, T, P} where {U, T, P}
    end
end))
println("declarations: ", errtext(edecl))

callres(f) = try (true, Base.invokelatest(f)) catch e; (false, inner_err(e)) end
show_r(r) = r[1] ? "returned $(repr(r[2]))" : errtext(r[2]; lines = 6)
typed_solve(p::ProbPkg.Prob{Vector{Float64}, Float64, Float64}) = Core1.solve(p, SolverPkg.Euler())
r1 = callres(() -> typed_solve(ProbPkg.Prob([1.0], (0.0, 1.0), 1.0)))
r2 = callres(() -> Core1.solve(ProbPkg.Prob(Float32[1], (0.0f0, 1.0f0), 1.0f0), SolverPkg.Euler()))
r3 = callres(() -> Core1.solve_dyn(ProbPkg.Prob([1.0], (0.0, 1.0), 1.0), SolverPkg.Euler()))
r0 = callres(() -> typeof(Core1.init_up(ProbPkg.Prob([1.0], (0.0, 1.0), 1.0), SolverPkg.Euler())))
println("typeof(init's result), handed up: ", show_r(r0))
println("solve, typed, Float64:  ", show_r(r1))
println("solve, top level, Float32: ", show_r(r2))
println("solve_dyn (no cast): ", show_r(r3))
# an init that returns a non-conforming value, or one at other parameters
toplevel(quote
    module ProbPkg2
    using TraitWorld
    using ..Core1, ..SolverPkg
    struct BadProb{U, T, P}; u0::U; tspan::Tuple{T, T}; p::P; end
    Core1.init(pr::BadProb, alg) = SolverPkg.EulerInteg(Float32.(pr.u0), Float32(pr.tspan[1]), pr.p, Float32.(pr.u0))   # at other parameters
    end
end)
ebad = caught(() -> toplevel(:(@eval ProbPkg2 @implement Core1.ODEProblemTrait BadProb{U, T, P} where {U, T, P})))
r4 = callres(() -> Core1.solve(ProbPkg2.BadProb([1.0], (0.0, 1.0), 1.0), SolverPkg.Euler()))
println("init at other parameters: declaration ", errtext(ebad; lines = 2), "; solve: ", show_r(r4))
println()

check("the trait with a trait-typed operation result is accepted", edef === nothing, errtext(edef; lines = 3))
check("the families (init by the problem's own method, generic in alg) are accepted", edecl === nothing, errtext(edecl; lines = 3))
check("solve from a typed caller: init's result is a Dynamic{Integrator{…}}, opened with compiled_for, runs",
      r1[1] && r1[2] ≈ 2.44140625, show_r(r1))
check("init's result is a Dynamic{Integrator{Vector{Float64}, Float64, Float64}}",
      r0 == (true, Dynamic{Core1.Integrator{Vector{Float64}, Float64, Float64}}), show_r(r0))
check("solve at the top level, Float32", r2[1] && r2[2] ≈ 2.4414062f0, show_r(r2))
check("the Dynamic result at the bound without a cast runs", r3[1] && r3[2] ≈ 2.44140625, show_r(r3))
check("an init returning an integrator at other parameters is refused (at the member's check or the call)",
      ebad isa ImplementError || (!r4[1] && (r4[2] isa ImplementError || r4[2] isa TraitBoundError || r4[2] isa TypeError)),
      "declaration: $(errtext(ebad; lines = 2)); solve: $(show_r(r4))")
finish("P12";
    predicted = "unprobed (option (d))",
    reference = "traits §3.1, §6.2: an operation's result declared with a trait is Dynamic (Implemented); §6.4: compiled_for opens it",
    prediction = "no prediction (unprobed)")
