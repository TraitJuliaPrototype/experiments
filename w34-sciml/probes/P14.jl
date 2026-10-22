# P14: the algorithm configured for a problem as a joint family (open issue 51, option (e), for the
# porting guideline): `Tsit5For{U, T, P}` implements `ODEAlgorithmFor{U, T, P}`, whose
# `init(a, u0, tspan, p)::Integrator{U, T, P}` names the trait's parameters; made by a typed
# `configure(alg::Tsit5, prob)`; the driver bounded by the problem and the configured algorithm at
# shared parameters.
# Reference: traits §4.7 (joint families), §3.1 (declared result types name the parameters), §6.2
# (an operation's result declared with a trait is Dynamic), §5.1 (shared variables), §5.5 (who may
# add a bounded method; lowering L-3). Unprobed (plan §1.4).
include("common.jl")
header("P14", "joint family Tsit5For{U, T, P} implementing ODEAlgorithmFor{U, T, P}; init(a, …)::Integrator{U, T, P}; configure(alg::Tsit5, prob)")

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
    end
    @trait ODEAlgorithmFor{U, T, P} begin
        init(a::ODEAlgorithmFor{U, T, P}, u0::U, tspan::Tuple{T, T}, p::P)::Integrator{U, T, P}
    end
    function run!(integ::Integrator{U, T, P}, tf::T, dt::T) where {U, T, P}
        while integ.t < tf
            step!(integ, dt)
        end
        return integ.u[1]
    end
    "The driver: the problem and the configured algorithm linked by their parameters."
    function solve(prob::ODEProblemTrait{U, T, P}, a::ODEAlgorithmFor{U, T, P}) where {U, T, P}
        integ = init(a, prob.u0, prob.tspan, prob.p)
        t0, tf = prob.tspan
        return run!(compiled_for(integ), tf, (tf - t0) / 4)
    end
    "The core's configure: solver packages add methods for their algorithms."
    configure(alg, prob::ODEProblemTrait) = throw(ArgumentError("no configure method for this algorithm"))
    "The W-34 plan's route for move 3 (§1.4): the core declares the bounded shape, solver packages extend it."
    __init(prob::ODEProblemTrait, alg) = throw(ArgumentError("no __init method for this algorithm"))
    end
end))
println("trait module: ", errtext(edef))

# the problem's package
toplevel(quote
    module ProbPkg
    using TraitWorld
    using ..Core1
    struct Prob{U, T, P}; u0::U; tspan::Tuple{T, T}; p::P; end
    @implement Core1.ODEProblemTrait Prob{U, T, P} where {U, T, P}
    end
end)
# the solver's package, a trait module: the algorithm, its configured form, the integrator; configure
# as a bounded method on the core's function
esol = caught(() -> toplevel(quote
    @trait_module module Tsit5Pkg
    using TraitWorld
    using ..Core1
    struct Tsit5 end
    struct Tsit5For{U, T, P} end
    mutable struct Tsit5Integ{U, T, P}; const u::U; t::T; const p::P; const du::U; end
    Core1.step!(i::Tsit5Integ, dt) = (i.du .= i.p .* i.u; u = i.u; u .+= dt .* i.du; i.t += dt; nothing)
    Core1.init(::Tsit5For{U, T, P}, u0::U, tspan::Tuple{T, T}, p::P) where {U, T, P} = Tsit5Integ{U, T, P}(copy(u0), tspan[1], p, similar(u0))
    @implement Core1.Integrator Tsit5Integ{U, T, P} where {U, T, P}
    @implement Core1.ODEAlgorithmFor{U, T, P} Tsit5For{U, T, P} where {U, T, P}
    Core1.configure(alg::Tsit5, prob::Core1.ODEProblemTrait{U, T, P}) where {U, T, P} = Tsit5For{U, T, P}()
    end
end))
println("solver package (trait module, bounded configure on the core's function): ", errtext(esol; lines = 4))
# the plan's §1.4 route on its own: a solver package's typed-and-bounded method on the core's `__init`
einit = caught(() -> toplevel(quote
    @trait_module module InitPkg
    using TraitWorld
    using ..Core1
    struct MyAlg end
    Core1.__init(prob::Core1.ODEProblemTrait, alg::MyAlg) = 1
    end
end))
println("solver package: `Core1.__init(prob::ODEProblemTrait, alg::MyAlg)` beside the core's `__init(prob::ODEProblemTrait, alg)`: ", errtext(einit; lines = 3))
# if the bounded configure is refused, the same solver package without it, configure typed in plain code
esol2 = nothing
if esol !== nothing
    global esol2 = caught(() -> toplevel(quote
        @trait_module module Tsit5Pkg2
        using TraitWorld
        using ..Core1
        struct Tsit5 end
        struct Tsit5For{U, T, P} end
        mutable struct Tsit5Integ{U, T, P}; const u::U; t::T; const p::P; const du::U; end
        Core1.step!(i::Tsit5Integ, dt) = (i.du .= i.p .* i.u; u = i.u; u .+= dt .* i.du; i.t += dt; nothing)
        Core1.init(::Tsit5For{U, T, P}, u0::U, tspan::Tuple{T, T}, p::P) where {U, T, P} = Tsit5Integ{U, T, P}(copy(u0), tspan[1], p, similar(u0))
        @implement Core1.Integrator Tsit5Integ{U, T, P} where {U, T, P}
        @implement Core1.ODEAlgorithmFor{U, T, P} Tsit5For{U, T, P} where {U, T, P}
        end
        configure2(::Tsit5Pkg2.Tsit5, prob::ProbPkg.Prob{U, T, P}) where {U, T, P} = Tsit5Pkg2.Tsit5For{U, T, P}()
    end))
    println("solver package without the bounded configure; configure typed in plain code: ", errtext(esol2; lines = 4))
end
println()

callres(f) = try (true, Base.invokelatest(f)) catch e; (false, inner_err(e)) end
show_r(r) = r[1] ? "returned $(repr(r[2]))" : errtext(r[2]; lines = 5)
prob = ProbPkg.Prob([1.0], (0.0, 1.0), 1.0)
if esol === nothing
    rc = callres(() -> typeof(Core1.configure(Tsit5Pkg.Tsit5(), prob)))
    rs = callres(() -> Core1.solve(prob, Core1.configure(Tsit5Pkg.Tsit5(), prob)))
    rmis = callres(() -> Core1.solve(prob, Tsit5Pkg.Tsit5For{Vector{Float32}, Float32, Float32}()))
else
    rc = callres(() -> typeof(configure2(Tsit5Pkg2.Tsit5(), prob)))
    rs = callres(() -> Core1.solve(prob, configure2(Tsit5Pkg2.Tsit5(), prob)))
    rmis = callres(() -> Core1.solve(prob, Tsit5Pkg2.Tsit5For{Vector{Float32}, Float32, Float32}()))
end
println("configure(Tsit5(), prob): ", show_r(rc))
println("solve(prob, configure(Tsit5(), prob)): ", show_r(rs))
println("solve(prob, a configured for Float32): ", show_r(rmis))
println()

check("the core trait module is accepted", edef === nothing, errtext(edef))
check("the solver package's bounded configure on the core's function is accepted (L-3 permits: the core has a method of that shape)",
      esol === nothing, errtext(esol; lines = 3))
check("the plan's §1.4 route: a solver package's `Core1.__init(prob::ODEProblemTrait, alg::MyAlg)` is accepted (traits §5.5; L-3: the core has a bounded method of that shape)",
      einit === nothing, errtext(einit; lines = 3))
check("the joint family Tsit5For{U, T, P} is accepted", esol === nothing || esol2 === nothing, "$(errtext(esol; lines = 2)); $(errtext(esol2; lines = 2))")
check("configure gives the configured algorithm at the problem's parameters", rc[1] && occursin("Tsit5For{Vector{Float64}, Float64, Float64}", string(rc[2])), show_r(rc))
check("solve runs: init's trait-typed result opened with compiled_for", rs[1] && rs[2] ≈ 2.44140625, show_r(rs))
check("an algorithm configured at other parameters is refused at the driver (TraitBoundError)", !rmis[1] && rmis[2] isa TraitBoundError, show_r(rmis))
finish("P14";
    predicted = "unprobed (option (e)); for the porting guideline",
    reference = "traits §4.7 joint families; §6.2: an operation's result declared with a trait is Dynamic (Implemented); §5.1 shared variables; §5.5 with lowering L-3 for the bounded configure",
    prediction = "no prediction (unprobed)")
