# P1c: the no-block family declared by a third package that owns neither the trait nor the type
# (the type's owner defined the methods). Both spellings, three trait shapes, and a single concrete
# type as the control.
# Reference: traits §4.9 ("Who: the declaring package owns the trait or the type"), §10.1 (a third
# package may not), §4.7 (the family's declaration checks ownership).
include("common.jl")
header("P1c", "@implement X S{T} where {T} / X A where {A <: S}, no block, by a third package")

toplevel(quote
    @trait_module module TraitPkg
    using TraitWorld
    @trait ODEAlgorithm begin
        alg_order(a::ODEAlgorithm)::Int
    end
    @trait IntegratorView{U, T, P} begin
        u::U
        t::T
        @const p::P
    end
    @trait SV{T} begin
        sget(s::SV{T}, i::Int)::T
    end
    describe(a::ODEAlgorithm) = alg_order(a)
    tview(i::IntegratorView{U, T, P}) where {U, T, P} = (U, T, P, i.t)
    first_of(s::SV{T}) where {T} = (T, sget(s, 1))
    end
end)

# the type's owner: types and methods, no declarations
toplevel(quote
    module SolverPkg
    using ..TraitPkg
    struct Tsit5{C}; c::C; end
    TraitPkg.alg_order(::Tsit5) = 5
    struct Rodas5{C}; c::C; end
    TraitPkg.alg_order(::Rodas5) = 4
    mutable struct Integ{U, T, P}; u::U; t::T; const p::P; end
    struct Ser{T}; data::Vector{T}; end
    TraitPkg.sget(s::Ser, i::Int) = s.data[i]
    struct Conc; c::Int; end
    TraitPkg.alg_order(::Conc) = 3
    end
end)

# the third package: owns neither the traits nor the types
decl(name, ex) = caught(() -> Core.eval(Main, Expr(:toplevel, :(module $name; using TraitWorld; using ..TraitPkg, ..SolverPkg; $ex; end))))
cases = [
    ("control: one concrete type, @implement ODEAlgorithm Conc", :(@implement TraitPkg.ODEAlgorithm SolverPkg.Conc)),
    ("operations, no parameters: ODEAlgorithm Tsit5{C} where {C}", :(@implement TraitPkg.ODEAlgorithm SolverPkg.Tsit5{C} where {C})),
    ("operations, no parameters: ODEAlgorithm A where {A <: Rodas5}", :(@implement TraitPkg.ODEAlgorithm A where {A <: SolverPkg.Rodas5})),
    ("fields with parameters: IntegratorView Integ{U, T, P} where {U, T, P}", :(@implement TraitPkg.IntegratorView SolverPkg.Integ{U, T, P} where {U, T, P})),
    ("joint: SV{T} Ser{T} where {T}", :(@implement TraitPkg.SV{T} SolverPkg.Ser{T} where {T})),
]
callres(f) = try (true, Base.invokelatest(f)) catch e; (false, inner_err(e)) end
show_r(r) = r[1] ? "returned $(repr(r[2]))" : errtext(r[2]; lines = 3)
calls = [
    () -> TraitPkg.describe(SolverPkg.Conc(1)),
    () -> TraitPkg.describe(SolverPkg.Tsit5(1)),
    () -> TraitPkg.describe(SolverPkg.Rodas5(1)),
    () -> TraitPkg.tview(SolverPkg.Integ([1.0], 0.5, nothing)),
    () -> TraitPkg.first_of(SolverPkg.Ser([2.0])),
]
results = []
for (k, ((lbl, ex), c)) in enumerate(zip(cases, calls))
    e = decl(Symbol(:Third, k), ex)
    r = callres(c)
    push!(results, (lbl, e, r))
    println(lbl)
    println("   declaration: ", errtext(e; lines = 3))
    println("   call:        ", show_r(r))
end
println()

for (lbl, e, r) in results
    refused = e isa ImplementError && occursin("owns neither", sprint(showerror, e))
    check("refused at the declaration (ImplementError, rule 3): " * lbl, refused,
          "declaration: $(errtext(e; lines = 2)); call afterwards: $(show_r(r))")
end

finish("P1c";
    predicted = "accepted: the no-block joint-form branch runs no ownership check (§4.9 says refused). If confirmed: a new T- row, W-38",
    reference = "traits §4.9 and §10.1: only the trait's or the type's owner may declare; a third package is refused (ImplementError)",
    prediction = "see the log: the prediction holds for each case that is accepted")
