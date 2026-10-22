# P11: the driver bounded by two traits at shared parameters (open issue 51, option (a+)):
# `solve!(integ::Integrator{U, T, P}, prob::ODEProblemTrait{U, T, P}) where {U, T, P}`. A matched
# pair runs; a pair whose parameters disagree raises TraitBoundError, from typed callers and from
# the top level.
# Reference: traits §3.4 (the link checked at each call), §5.1 (a variable shared between bounds
# requires equal values: TraitBoundError). Implemented.
include("common.jl")
header("P11", "solve!(integ::Integrator{U, T, P}, prob::ODEProblemTrait{U, T, P}) where {U, T, P}; a mismatched pair raises TraitBoundError")

edef = caught(() -> toplevel(quote
    @trait_module module Core1
    using TraitWorld
    @trait ODEProblemTrait{U, T, P} begin
        @const u0::U
        @const tspan::Tuple{T, T}
        @const p::P
        rhs!(prob::ODEProblemTrait{U, T, P}, du::U, u::U, t::T)::Nothing
    end
    @trait Integrator{U, T, P} begin
        @const u::U
        t::T
        @const p::P
        @const du::U
    end
    "The driver: the link between the integrator and the problem checked at the call."
    function solve!(integ::Integrator{U, T, P}, prob::ODEProblemTrait{U, T, P}) where {U, T, P}
        t0, tf = prob.tspan
        dt = (tf - t0) / 4
        while integ.t < tf
            rhs!(prob, integ.du, integ.u, integ.t)
            u = integ.u                       # `integ.u .+= …` is checked separately (dot_update!)
            u .+= dt .* integ.du
            integ.t += dt
        end
        return (U, T, P, integ.u[1])
    end
    "A broadcast update of a declared field in place, `integ.u .+= integ.du` (Julia lowers it to `Base.dotgetproperty`)."
    dot_update!(integ::Integrator{U, T, P}) where {U, T, P} = (integ.u .+= integ.du; integ.u[1])
    end
end))
println("trait module: ", errtext(edef))
edecl = caught(() -> toplevel(quote
    module ProbPkg                      # the problem's package
    using TraitWorld
    using ..Core1
    struct Prob{U, T, P}; u0::U; tspan::Tuple{T, T}; p::P; end
    Core1.rhs!(pr::Prob, du, u, t) = (du .= pr.p .* u; nothing)
    @implement Core1.ODEProblemTrait Prob{U, T, P} where {U, T, P}
    end
    module SolverPkg                    # the solver's package
    using TraitWorld
    using ..Core1
    mutable struct Integ{U, T, P}; const u::U; t::T; const p::P; const du::U; end
    @implement Core1.Integrator Integ{U, T, P} where {U, T, P}
    start(pr) = Integ(copy(pr.u0), pr.tspan[1], pr.p, similar(pr.u0))
    end
end))
println("declarations: ", errtext(edecl))

callres(f) = try (true, Base.invokelatest(f)) catch e; (false, inner_err(e)) end
show_r(r) = r[1] ? "returned $(repr(r[2]))" : errtext(r[2]; lines = 4)
P = ProbPkg; S = SolverPkg
prob64 = P.Prob([1.0], (0.0, 1.0), 1.0)
prob32 = P.Prob(Float32[1], (0.0f0, 1.0f0), 1.0f0)
typed_match(i::S.Integ{Vector{Float64}, Float64, Float64}, p::P.Prob{Vector{Float64}, Float64, Float64}) = Core1.solve!(i, p)
typed_mis(i::S.Integ{Vector{Float32}, Float32, Float32}, p::P.Prob{Vector{Float64}, Float64, Float64}) = Core1.solve!(i, p)
typed_misP(i::S.Integ{Vector{Float64}, Float64, Int}, p::P.Prob{Vector{Float64}, Float64, Float64}) = Core1.solve!(i, p)
rs = [
    ("matched (Float64), typed", callres(() -> typed_match(S.start(prob64), prob64)), :ok),
    ("matched (Float32), top level", callres(() -> Core1.solve!(S.start(prob32), prob32)), :ok),
    ("U, T disagree (Float32 integrator, Float64 problem), typed", callres(() -> typed_mis(S.start(prob32), prob64)), :tbe),
    ("U, T disagree, top level", callres(() -> Core1.solve!(S.start(prob32), prob64)), :tbe),
    ("P disagrees (Int against Float64), typed", callres(() -> typed_misP(S.Integ([1.0], 0.0, 1, [0.0]), prob64)), :tbe),
    ("P disagrees, top level", callres(() -> Core1.solve!(S.Integ([1.0], 0.0, 1, [0.0]), prob64)), :tbe),
]
for (lbl, r, _) in rs
    println(rpad(lbl, 62), show_r(r))
end
rdot = callres(() -> Core1.dot_update!(S.Integ([1.0], 0.0, 1.0, [2.0])))
println(rpad("integ.u .+= integ.du on a declared field", 62), show_r(rdot))
println()
check("the trait module and the families are accepted", edef === nothing && edecl === nothing, "$(errtext(edef)); $(errtext(edecl))")
for (lbl, r, want) in rs
    ok = want === :ok ? (r[1] && r[2][4] ≈ 2.44140625) : (!r[1] && r[2] isa TraitBoundError)
    check(lbl * (want === :ok ? ": runs (u = 2.4414…)" : ": TraitBoundError"), ok, show_r(r))
end
check("`integ.u .+= integ.du` on a declared field (traits §3.3: bounded code reads declared fields) runs", rdot == (true, 3.0), show_r(rdot))
finish("P11";
    predicted = "works (open issue 51, option (a+))",
    reference = "traits §3.4, §5.1: a variable shared between bounds requires equal values, TraitBoundError otherwise. Implemented",
    prediction = "see the checks: yes where every check is ok")
