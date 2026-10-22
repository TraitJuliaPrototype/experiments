# P9: a no-block family over a mutable type with its own `getproperty` (as SciML's DEIntegrator),
# every declared field mapped, operations by the owner's existing methods; declared outside the
# trait's module by the type's owner.
# Reference: traits §3.3 (a declared field is read from the stored field, never through getproperty;
# a type with its own getproperty conforms only if it maps every declared field), §4.4 (field
# mappings), §4.7 (families). Implemented.
include("common.jl")
header("P9", "@implement IntegratorView DEInt{U, T, P} where {U, T, P} u => u, t => _t, p => p (own getproperty)")

toplevel(quote
    @trait_module module TraitPkg
    using TraitWorld
    @trait IntegratorView{U, T, P} begin
        @const u::U
        t::T
        @const p::P
        add_tstop!(i::IntegratorView, t)::Nothing
    end
    readall(i::IntegratorView{U, T, P}) where {U, T, P} = (U, T, P, i.u[1], i.t, i.p)
    bump!(i::IntegratorView{U, T, P}, dt::T) where {U, T, P} = (i.t = i.t + dt; add_tstop!(i, i.t); nothing)
    @trait Flagged begin
        u_modified::Bool                                   # writable, of a fixed type
    end
    setflag!(f::Flagged) = (f.u_modified = true; nothing)
    end
end)

# the integrator's owner: a mutable type with its own getproperty (aliases and a computed property),
# one field stored under another name
edecl = caught(() -> toplevel(quote
    module SolverPkg
    using TraitWorld
    using ..TraitPkg
    mutable struct DEInt{U, T, P}
        const u::U
        _t::T
        const p::P
        const tstops::Vector{T}
    end
    function Base.getproperty(i::DEInt, s::Symbol)
        s === :t && return getfield(i, :_t)
        s === :t_alias && return getfield(i, :_t)
        s === :p && return :not_the_stored_p              # plain x.p differs from t.p on purpose
        s === :nstops && return length(getfield(i, :tstops))
        return getfield(i, s)
    end
    TraitPkg.add_tstop!(i::DEInt, t) = (push!(getfield(i, :tstops), t); nothing)
    @implement TraitPkg.IntegratorView DEInt{U, T, P} where {U, T, P} u => u, t => _t, p => p
    # the same type shape, its getproperty, no mapping: to be refused
    mutable struct NoMap{U, T, P}
        const u::U
        t::T
        const p::P
    end
    Base.getproperty(i::NoMap, s::Symbol) = getfield(i, s)
    TraitPkg.add_tstop!(i::NoMap, t) = nothing
    end
end))
println("declarations: ", errtext(edecl))
enomap = caught(() -> toplevel(:(@eval SolverPkg @implement TraitPkg.IntegratorView NoMap{U, T, P} where {U, T, P})))
println("the family without mappings: ", errtext(enomap; lines = 3))
# controls and the other field checks for family members (traits §4.9: every declared field exists,
# with the declared type; a writable field needs a mutable type and a non-const stored field)
toplevel(quote
    module Others
    using TraitWorld
    using ..TraitPkg
    mutable struct OneGP; const u::Vector{Float64}; t::Float64; const p::Int; end      # one concrete type, own getproperty
    Base.getproperty(i::OneGP, s::Symbol) = getfield(i, s)
    TraitPkg.add_tstop!(i::OneGP, t) = nothing
    mutable struct GoodF{T}; x::T; u_modified::Bool; end
    mutable struct BadF{T}; x::T; u_modified::Int; end                 # the declared type is Bool
    mutable struct ConstF{T}; x::T; const u_modified::Bool; end        # const where the trait writes
    struct MissF{T}; x::T; end                                         # no such field
    end
end)
eone = caught(() -> toplevel(:(@eval Others @implement TraitPkg.IntegratorView{Vector{Float64}, Float64, Int} OneGP)))
println("control, one concrete type with its own getproperty, no mappings: ", errtext(eone; lines = 3))
fams = [(:GoodF, "GoodF (u_modified::Bool)"), (:BadF, "BadF (u_modified::Int)"), (:ConstF, "ConstF (const u_modified)"), (:MissF, "MissF (no field)")]
fdecl = Dict{Symbol,Any}()
for (nm, _) in fams
    fdecl[nm] = caught(() -> toplevel(:(@eval Others @implement TraitPkg.Flagged $nm{T} where {T})))
end
callres0(f) = try (true, Base.invokelatest(f)) catch e; (false, inner_err(e)) end
fuse = Dict{Symbol,Any}()
mkf = Dict(:GoodF => () -> Others.GoodF(1, false), :BadF => () -> Others.BadF(1, 0),
           :ConstF => () -> Others.ConstF(1, false), :MissF => () -> Others.MissF(1))
for (nm, lbl) in fams
    fuse[nm] = callres0(() -> (o = mkf[nm](); TraitPkg.setflag!(o); (getfield(o, :x), getfield(o, :u_modified))))
    println("family ", rpad(lbl, 28), " declaration: ", errtext(fdecl[nm]; lines = 2), "\n        first use (setflag!): ",
            fuse[nm][1] ? "returned $(repr(fuse[nm][2]))" : errtext(fuse[nm][2]; lines = 2))
end

callres(f) = try (true, Base.invokelatest(f)) catch e; (false, inner_err(e)) end
show_r(r) = r[1] ? "returned $(repr(r[2]))" : errtext(r[2]; lines = 4)
mk() = SolverPkg.DEInt([1.0], 0.5, (a = 2,), Float64[])
typed_read(i::SolverPkg.DEInt{Vector{Float64}, Float64, @NamedTuple{a::Int}}) = TraitPkg.readall(i)
typed_bump(i::SolverPkg.DEInt{Vector{Float64}, Float64, @NamedTuple{a::Int}}) = (TraitPkg.bump!(i, 0.25); (getfield(i, :_t), i.nstops))
r1 = callres(() -> typed_read(mk()))
r2 = callres(() -> TraitPkg.readall(mk()))
r3 = callres(() -> typed_bump(mk()))
r4 = callres(() -> TraitPkg.readall(SolverPkg.NoMap([1.0], 0.5, 1)))
println("readall, typed:          ", show_r(r1))
println("readall, top level:      ", show_r(r2))
println("bump! (write t, add_tstop!), typed: ", show_r(r3))
println("plain getproperty still serves plain code: x.p = ", repr(mk().p), ", x.t_alias = ", mk().t_alias)
println("NoMap member at its first use: ", show_r(r4))
println()
want = (Vector{Float64}, Float64, @NamedTuple{a::Int}, 1.0, 0.5, (a = 2,))
check("the family with every field mapped is accepted", edecl === nothing, errtext(edecl))
check("declared fields read from the stored fields (t from _t, p the stored p, not getproperty's), typed", r1 == (true, want), show_r(r1))
check("the same at the top level (Dynamic)", r2 == (true, want), show_r(r2))
check("a write of t through the trait reaches the stored _t; add_tstop! by the existing method", r3 == (true, (0.75, 1)), show_r(r3))
refused_nomap = (enomap isa ImplementError) || (enomap === nothing && !r4[1] && r4[2] isa ImplementError)
check("a family member with its own getproperty and no mappings is refused (at the declaration or its first use)", refused_nomap,
      "declaration: $(errtext(enomap; lines = 2)); first use: $(show_r(r4))")
check("control: one concrete type with its own getproperty and no mappings is refused at the declaration", eone isa ImplementError, errtext(eone; lines = 2))
check("family GoodF{T}: works", fdecl[:GoodF] === nothing && fuse[:GoodF] == (true, (1, true)), "$(errtext(fdecl[:GoodF])); $(fuse[:GoodF])")
for nm in (:BadF, :ConstF, :MissF)
    ok = fdecl[nm] isa ImplementError || (fdecl[nm] === nothing && !fuse[nm][1] && fuse[nm][2] isa ImplementError)
    check("family $(nm){T}: refused (ImplementError at the declaration or the first use)", ok,
          "declaration: $(errtext(fdecl[nm]; lines = 2)); first use: $(fuse[nm][1] ? "returned $(repr(fuse[nm][2]))" : errtext(fuse[nm][2]; lines = 2))")
end
finish("P9";
    predicted = "works",
    reference = "traits §3.3, §4.4, §4.7: Implemented; a type with its own getproperty must map every declared field",
    prediction = "see the checks: yes where every check is ok")
