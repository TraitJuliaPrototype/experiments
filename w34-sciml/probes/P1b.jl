# P1b: families without a block, `S{T} where {T}` and `A where {A <: S}`, declared by the type's
# owner outside the trait's module, the type's methods defined before; members checked at first use.
# Three trait shapes the moves need: operations without parameters (ODEAlgorithm), a trait of fields
# with parameters plus an operation (IntegratorView{U, T, P}), and the joint form (SV{T} Ser{T}).
# Reference: traits §4.7 (Implemented), §10.1 (the type's owner may implement).
include("common.jl")
header("P1b", "@implement X S{T} where {T} and @implement X A where {A <: S}, no block, by S's owner outside the trait's module")

toplevel(quote
    @trait_module module TraitPkg
    using TraitWorld
    export ODEAlgorithm, alg_order, isadaptive, IntegratorView, nsteps, SV, sget
    @trait ODEAlgorithm begin
        alg_order(a::ODEAlgorithm)::Int
        isadaptive(a::ODEAlgorithm)::Bool = true
    end
    @trait IntegratorView{U, T, P} begin
        u::U
        t::T
        @const p::P
        nsteps(i::IntegratorView)::Int
    end
    @trait SV{T} begin
        sget(s::SV{T}, i::Int)::T
    end
    describe(a::ODEAlgorithm) = (alg_order(a), isadaptive(a))
    ipeek(i::IntegratorView{U, T, P}) where {U, T, P} = (U, T, P, i.t, nsteps(i))
    advance!(i::IntegratorView{U, T, P}, dt::T) where {U, T, P} = (i.t = i.t + dt; nothing)
    first_of(s::SV{T}) where {T} = (T, sget(s, 1))
    end
end)

# the solver package: a plain module that owns its types and declares their implementations
edecl = caught(() -> toplevel(quote
    module SolverPkg
    using TraitWorld
    using ..TraitPkg
    struct Tsit5{C}; c::C; end
    TraitPkg.alg_order(::Tsit5) = 5
    @implement TraitPkg.ODEAlgorithm Tsit5{C} where {C}            # the type expression form

    struct Rodas5{C}; c::C; end
    TraitPkg.alg_order(::Rodas5) = 4
    TraitPkg.isadaptive(::Rodas5) = false                           # overrides the default
    @implement TraitPkg.ODEAlgorithm A where {A <: Rodas5}          # the variable form

    struct Bad{T}; x::T; end
    TraitPkg.alg_order(b::Bad) = b.x                                # Int for Bad{Int}, not for Bad{Float64}
    @implement TraitPkg.ODEAlgorithm Bad{T} where {T}

    mutable struct Integ{U, T, P}
        u::U
        t::T
        const p::P
        n::Int
    end
    TraitPkg.nsteps(i::Integ) = i.n
    @implement TraitPkg.IntegratorView Integ{U, T, P} where {U, T, P}

    struct Ser{T}; data::Vector{T}; end
    TraitPkg.sget(s::Ser, i::Int) = s.data[i]
    @implement TraitPkg.SV{T} Ser{T} where {T}                     # joint: the trait's T is the type's T
    end
end))
println("declarations: ", errtext(edecl))
println()

callres(f) = try (true, Base.invokelatest(f)) catch e; (false, inner_err(e)) end
show_r(r) = r[1] ? "returned $(repr(r[2]))" : errtext(r[2]; lines = 4)
P = TraitPkg; S = SolverPkg

# from the top level (Dynamic) and from typed callers (Compiled)
typed_tsit(a::SolverPkg.Tsit5{Symbol}) = TraitPkg.describe(a)
typed_rodas(a::SolverPkg.Rodas5{Int}) = TraitPkg.describe(a)
typed_peek(i::SolverPkg.Integ{Vector{Float64}, Float64, Nothing}) = TraitPkg.ipeek(i)
typed_adv(i::SolverPkg.Integ{Vector{Float64}, Float64, Nothing}) = (TraitPkg.advance!(i, 0.5); i.t)
typed_ser(s::SolverPkg.Ser{Float32}) = TraitPkg.first_of(s)

rs = [
 ("Tsit5{Int} at the top level", callres(() -> P.describe(S.Tsit5(1))), (5, true)),
 ("Tsit5{Symbol} from a typed caller", callres(() -> typed_tsit(S.Tsit5(:a))), (5, true)),
 ("Rodas5{Int} (A where {A <: Rodas5}) typed", callres(() -> typed_rodas(S.Rodas5(1))), (4, false)),
 ("Rodas5{String} at the top level", callres(() -> P.describe(S.Rodas5("x"))), (4, false)),
 ("Integ: ipeek, typed", callres(() -> typed_peek(S.Integ([1.0], 0.0, nothing, 3))), (Vector{Float64}, Float64, Nothing, 0.0, 3)),
 ("Integ: write t through the trait, typed", callres(() -> typed_adv(S.Integ([1.0], 1.0, nothing, 0))), 1.5),
 ("Integ{Vector{Float32},Float32,Symbol} at the top level", callres(() -> P.ipeek(S.Integ(Float32[1], 0.0f0, :p, 1))), (Vector{Float32}, Float32, Symbol, 0.0f0, 1)),
 ("Ser{Float32} (joint), typed", callres(() -> typed_ser(S.Ser(Float32[2]))), (Float32, 2.0f0)),
 ("Ser{Int} (joint) at the top level", callres(() -> P.first_of(S.Ser([7]))), (Int, 7)),
 ("Bad{Int} conforms", callres(() -> P.describe(S.Bad(3))), (3, true)),
]
for (lbl, r, want) in rs
    println(rpad(lbl, 58), show_r(r))
end
rbad = callres(() -> P.describe(S.Bad(3.0)))
println(rpad("Bad{Float64}: alg_order returns Float64", 58), show_r(rbad))
println()

check("the declarations are accepted (by the type's owner, outside the trait's module)", edecl === nothing, errtext(edecl))
for (lbl, r, want) in rs
    check(lbl, r[1] && isequal(r[2], want), "want $(repr(want)); $(show_r(r))")
end
check("a member that does not conform is refused at its first use (ImplementError)",
      !rbad[1] && rbad[2] isa ImplementError && occursin("member of a family", sprint(showerror, rbad[2])), show_r(rbad))

finish("P1b";
    predicted = "works; members checked at first use",
    reference = "traits §4.7: a family without a block, by the type's own methods, Implemented; each member checked at its first use; §10.1: the type's owner may declare",
    prediction = "see the checks: yes where every check is ok")
