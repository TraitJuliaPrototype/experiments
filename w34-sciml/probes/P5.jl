# P5: a parametric subtrait, `Integrator{U, T, P} <: IntegratorView{U, T, P}`, implemented by a
# solver's integrator family (no block, by the owner's methods, outside the trait's module); a bound
# on the subtrait beats the supertrait; the subtrait's parameters read in a bound.
# Reference: traits §3.6 (Implemented; the grammar's `Supertraits ::= TraitExpr`, a TraitRef with
# parameters), §5.5 ("a subtrait beats its supertrait"), §4.7.
# Variant A is the plan's form. Variant B, the supertrait named bare and the subtrait's parameters
# stated by a joint family, is what TraitWorld takes if A is refused.
include("common.jl")
header("P5", "@trait Integrator{U, T, P} <: IntegratorView{U, T, P}; a bound on the subtrait beats the supertrait")

callres(f) = try (true, Base.invokelatest(f)) catch e; (false, inner_err(e)) end
show_r(r) = r[1] ? "returned $(repr(r[2]))" : errtext(r[2]; lines = 4)

# --- variant A: the plan's form ------------------------------------------------------------
eA = caught(() -> toplevel(quote
    @trait_module module TraitA
    using TraitWorld
    @trait IntegratorView{U, T, P} begin
        u::U
        t::T
        @const p::P
    end
    @trait Integrator{U, T, P} <: IntegratorView{U, T, P} begin
        step!(i::Integrator)::Nothing
        done(i::Integrator)::Bool
    end
    end
end))
println("A: `@trait Integrator{U, T, P} <: IntegratorView{U, T, P}`: ", errtext(eA; lines = 3))
eA2 = nothing
if eA === nothing
    global eA2 = caught(() -> toplevel(quote
        module SolverA
        using TraitWorld
        using ..TraitA
        mutable struct Integ{U, T, P}; u::U; t::T; const p::P; tend::T; end
        TraitA.step!(i::Integ) = (i.t += one(i.t); nothing)
        TraitA.done(i::Integ) = i.t >= i.tend
        @implement TraitA.IntegratorView Integ{U, T, P} where {U, T, P}
        @implement TraitA.Integrator Integ{U, T, P} where {U, T, P}
        end
    end))
    println("A: the family declarations: ", errtext(eA2; lines = 3))
end
# A, continued: the joint form for the subtrait, then a bounded function on the subtrait
eA3 = caught(() -> toplevel(quote
    module SolverA3
    using TraitWorld
    using ..TraitA
    mutable struct Integ{U, T, P}; u::U; t::T; const p::P; tend::T; end
    TraitA.step!(i::Integ) = (i.t += one(i.t); nothing)
    TraitA.done(i::Integ) = i.t >= i.tend
    @implement TraitA.IntegratorView Integ{U, T, P} where {U, T, P}
    @implement TraitA.Integrator{U, T, P} Integ{U, T, P} where {U, T, P}
    end
end))
println("A: the joint form `@implement Integrator{U, T, P} Integ{U, T, P} where {U, T, P}`: ", errtext(eA3; lines = 3))
eA4 = caught(() -> toplevel(quote
    @trait_module module UseA
    using TraitWorld
    using ..TraitA
    kindA(i::TraitA.IntegratorView) = :view
    kindA(i::TraitA.Integrator) = :integrator
    end
end))
println("A: a bounded function on the subtrait (`kindA(i::Integrator)`): ", errtext(eA4; lines = 3))
rA = eA4 === nothing && eA3 === nothing ? callres(() -> UseA.kindA(SolverA3.Integ([1.0], 0.0, nothing, 1.0))) : (false, "not reached")
println("A: kindA(Integ): ", show_r(rA))
println()

# --- variant B: the supertrait bare; the subtrait's parameters stated by the joint form -------
eB = caught(() -> toplevel(quote
    @trait_module module TraitB
    using TraitWorld
    @trait IntegratorView{U, T, P} begin
        u::U
        t::T
        @const p::P
    end
    @trait Integrator{U, T, P} <: IntegratorView begin
        step!(i::Integrator)::Nothing
        done(i::Integrator)::Bool
    end
    kind(i::IntegratorView) = :view
    kind(i::Integrator) = :integrator
    iparams(i::Integrator{U, T, P}) where {U, T, P} = (U, T, P)
    function drive!(i::Integrator{U, T, P}) where {U, T, P}
        n = 0
        while !done(i)
            step!(i)
            n += 1
        end
        return (n, i.t)                          # a supertrait's field through the subtrait's bound
    end
    end
end))
println("B: `@trait Integrator{U, T, P} <: IntegratorView`: ", errtext(eB; lines = 3))
eB1 = caught(() -> toplevel(quote
    module SolverB1
    using TraitWorld
    using ..TraitB
    mutable struct Integ{U, T, P}; u::U; t::T; const p::P; tend::T; end
    TraitB.step!(i::Integ) = (i.t += one(i.t); nothing)
    TraitB.done(i::Integ) = i.t >= i.tend
    @implement TraitB.IntegratorView Integ{U, T, P} where {U, T, P}
    @implement TraitB.Integrator Integ{U, T, P} where {U, T, P}      # parameters left to the fields
    end
end))
println("B: `@implement Integrator Integ{U, T, P} where {U, T, P}` (no parameters stated): ", errtext(eB1; lines = 3))
eB2 = caught(() -> toplevel(quote
    module SolverB
    using TraitWorld
    using ..TraitB
    mutable struct Integ{U, T, P}; u::U; t::T; const p::P; tend::T; end
    TraitB.step!(i::Integ) = (i.t += one(i.t); nothing)
    TraitB.done(i::Integ) = i.t >= i.tend
    @implement TraitB.IntegratorView Integ{U, T, P} where {U, T, P}
    @implement TraitB.Integrator{U, T, P} Integ{U, T, P} where {U, T, P}   # joint: parameters stated
    mutable struct ViewOnly{U, T, P}; u::U; t::T; const p::P; end
    @implement TraitB.IntegratorView ViewOnly{U, T, P} where {U, T, P}
    end
end))
println("B: `@implement Integrator{U, T, P} Integ{U, T, P} where {U, T, P}` (joint): ", errtext(eB2; lines = 3))
println()

rs = Any[]
if eB2 === nothing
    SP = SolverB
    typed_kind(i::SolverB.Integ{Vector{Float64}, Float64, Nothing}) = TraitB.kind(i)
    typed_drive(i::SolverB.Integ{Vector{Float64}, Float64, Nothing}) = TraitB.drive!(i)
    global rs = [
        ("B: kind(Integ) at the top level", callres(() -> TraitB.kind(SP.Integ([1.0], 0.0, nothing, 3.0))), :integrator),
        ("B: kind(Integ) from a typed caller", callres(() -> typed_kind(SP.Integ([1.0], 0.0, nothing, 3.0))), :integrator),
        ("B: kind(ViewOnly): the supertrait's method", callres(() -> TraitB.kind(SP.ViewOnly([1.0], 0.0, nothing))), :view),
        ("B: iparams(Integ{Vector{Float32}, Float32, Symbol})", callres(() -> TraitB.iparams(SP.Integ(Float32[1], 0.0f0, :p, 2.0f0))), (Vector{Float32}, Float32, Symbol)),
        ("B: drive!(Integ) typed: operations and the supertrait's field", callres(() -> typed_drive(SP.Integ([1.0], 0.0, nothing, 3.0))), (3, 3.0)),
    ]
    for (lbl, r, want) in rs
        println(rpad(lbl, 62), show_r(r))
    end
    println()
end

check("A: the plan's form `Integrator{U, T, P} <: IntegratorView{U, T, P}` is declared, implemented and used",
      eA === nothing && (eA2 === nothing || eA3 === nothing) && eA4 === nothing && rA == (true, :integrator),
      "trait: $(errtext(eA; lines = 2)); family (fields' parameters): $(errtext(eA2; lines = 2)); family (joint): $(errtext(eA3; lines = 2)); bounded function: $(errtext(eA4; lines = 2)); call: $(show_r(rA))")
check("B: the supertrait named bare, the subtrait's own parameters: accepted", eB === nothing, errtext(eB; lines = 2))
check("B: the subtrait implemented by the joint family (parameters stated)", eB2 === nothing, errtext(eB2; lines = 2))
for (lbl, r, want) in rs
    check(lbl, r[1] && isequal(r[2], want), "want $(repr(want)); $(show_r(r))")
end
println("\nnote: in B nothing ties Integrator's U, T, P to IntegratorView's: a family could state other values.")

finish("P5";
    predicted = "works",
    reference = "traits §3.6: supertraits Implemented; the grammar takes a supertrait with parameters (`TraitExpr`); no rule says how a supertrait's parameters relate to the subtrait's; §5.5: a subtrait beats its supertrait",
    prediction = "no for the plan's form (variant A); variant B as the checks say")
