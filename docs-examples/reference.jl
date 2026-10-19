# The examples of writeup/reference/traits.md that the tutorial does not run, with checks of what
# the page states, including its Deviations (checks named by their ID, T-n). Run from TraitWorld/:
#   JULIA_PKG_OFFLINE=true nice -n 19 ../julia-1.13/julia --project=. --startup-file=no ../experiments/docs-examples/reference.jl
include(joinpath(@__DIR__, "common.jl"))
using TraitWorld

# --- §2: the block form inside an ordinary module ------------------------------------------------
module BlockPkg
using TraitWorld
@trait_module begin
    @trait Counted begin
        count1(c::Counted)::Int
    end
    @implement Counted Vector{Int} begin
        count1(c) = length(c)
    end
    twice(c::Counted) = 2 * count1(c)
end
end
check("§2 @trait_module begin … end inside a module", BlockPkg.twice([1, 2, 3]) == 6)

# --- §3, §5, §6, §8: tables ----------------------------------------------------------------------
@trait_module module Columns
using TraitWorld
export ColTable, ncols, col, firstcol, RowTable, nrows, row, Table, colmean, colrange, describe, overview,
       overview2, both_len, fc, colz, colmean_or, cm_all, ncols_sum, kwrest, colmap, colsum, both,
       Iterable, gsum, KTable, kncols, kcol, kwith, kscaled, LRec, shifted, Stepper, nsteps, elapsed,
       KVec, klen, kget, kpair, Sized, sizes, ArrayLike, alen, firstof, Fam, nf, dbl, S, d2

@trait ColTable begin
    ncols(t::ColTable)::Int
    col(t::ColTable, i::Int)::Vector{Float64}
    firstcol(t::ColTable)::Vector{Float64} = col(t, 1)
end
@implement ColTable Vector{Vector{Float64}} begin
    ncols(t) = length(t)
    col(t, i) = t[i]
end
@implement ColTable Matrix{Float64} begin
    ncols(t) = size(t, 2)
    col(t, i) = t[:, i]
end
@trait RowTable begin
    nrows(t::RowTable)::Int
    row(t::RowTable, i::Int)::Vector{Float64}
end
@implement RowTable Matrix{Float64} begin
    nrows(t) = size(t, 1)
    row(t, i) = t[i, :]
end
@trait Table <: (ColTable, RowTable)   # a bundle: no body

colmean(t::ColTable, i::Int) = (c = col(t, i); sum(c) / length(c))
colrange(t::ColTable, i::Int) = (c = col(t, i); maximum(c) - minimum(c))
overview(t::(ColTable, RowTable)) = (colmean(t, 1), row(t, 1))
overview2(t::Table) = (colmean(t, 1), row(t, 1))
both_len(t::ColTable, v::Vector{T}) where {T} = ncols(t) + length(v)      # an ordinary where variable
fc(t::ColTable) = firstcol(t)

# §6.5
describe(v::Vector{Float64}) = "a vector"
describe(m::AbstractMatrix) = "a matrix"
describe(t::ColTable) = "a table with $(ncols(t)) columns"
describe(x) = "something else"                 # the entry's fallback

# §8
colz(t::ColTable, i::Int; baseline::ColTable = t, tol::Float64 = eps()) =
    (col(t, i) .- colmean(baseline, i)) ./ max(colrange(baseline, i), tol)
colmean_or(t::ColTable, i::Int = 1) = colmean(t, i)
cm_all(t::ColTable; cols = 1:ncols(t), scale = 1.0) = [colmean(t, i) * scale for i in cols]
ncols_sum(ts::ColTable...) = sum(ncols(t) for t in ts; init = 0)
kwrest(t::ColTable; kws...) = (ncols(t), length(kws))

# §9
colmap(f::Callable{Tuple{Float64}, Float64}, t::ColTable, i::Int) = map(f, col(t, i))                # default mode: DynamicCall
colsum(f::Callable{Tuple{Float64}, Float64, CompiledCall}, t::ColTable, i::Int) = sum(f, col(t, i))  # default mode: CompiledCall
both(f::(Callable{Tuple{Float64}, Float64}, Callable{Tuple{Int}, Int}), x::Float64, n::Int) = (f(x), f(n))

# §3.1
@trait Iterable begin
    Base.iterate(t::Iterable)::Union{Nothing, Tuple{eltype(Self), Any}}
    Base.iterate(t::Iterable, state)::Union{Nothing, Tuple{eltype(Self), Any}}
end
@implement Iterable A where {A <: AbstractArray}
gsum(t::Iterable) = (s = 0.0; for x in t; s += x; end; s)

# §3.5, §7
@trait KTable begin
    kncols(t::KTable)::Int
    kcol(t::KTable, i::Int)::Vector{Float64}
    kwith(t::KTable, cs::Vector{Vector{Float64}})::Self      # a constructor operation
end
@implement KTable Vector{Vector{Float64}} begin
    kncols(t) = length(t)
    kcol(t, i) = t[i]
    kwith(t, cs) = cs
end
kscaled(t::KTable, a::Float64)::Like{t} = kwith(t, [a .* kcol(t, i) for i in 1:kncols(t)])
@trait LRec{U} begin
    @const u::U
    @const label::String
end
shifted(r::LRec{Vector{Float64}})::Like{r} = withfields(r; u = r.u .+ 1.0)

# §5.4: a declared field mapped, with forwarding
@trait Stepper begin
    @const t::Float64
    nsteps(s::Stepper)::Int
end
@implement Stepper Vector{Float64} begin
    nsteps(v) = length(v)
end
elapsed(s::Stepper) = s.t * nsteps(s)

# §3.4
@trait KVec{T} begin
    T = eltype(Self)
    klen(v::KVec)::Int
    kget(v::KVec{T}, i::Int)::T
end
@implement KVec A where {A <: Vector{<:Real}} begin
    klen(v) = length(v)
    kget(v, i) = v[i]
end
kpair(a::KVec{T}, b::KVec{T}) where {T} = kget(a, 1) + kget(b, 1)      # planned: a shared parameter

@trait ArrayLike{T <: Real, N} begin       # a bounded parameter: accepted, not checked
    alen(a::ArrayLike)::Int
    firstof(a::ArrayLike{T})::T
end

# §12.1: an existing function as an operation, declared by its existing methods
@trait Sized begin
    Base.size(s::Sized)::Tuple{Int}
end
@implement Sized Vector{Float32}
sizes(s::Sized) = size(s)[1]

# §5.7: a family by its own methods
@trait Fam begin
    nf(x::Fam)::Int
    dbl(x::Fam)::Int = 2 * nf(x)
end
struct S{P}; p::P; k::Int; end
nf(s::S) = s.k
@implement Fam S{P} where {P}
d2(x::Fam) = dbl(x)
end
using .Columns

check("§5.1 a block for the library's own type", colmean([[1.0, 3.0]], 1) == 2.0)
check("§3.2 a default through trait code", fc([[5.0], [1.0]]) == [5.0])

# §5.2 one line, own methods; forwarding
struct Ramp; base::Vector{Float64}; n::Int; end
Columns.ncols(r::Ramp) = r.n
Columns.col(r::Ramp, i::Int) = r.base .* i
@implement ColTable Ramp           # Ramp has methods of ncols and col
struct Measurements; label::String; data::Vector{Vector{Float64}}; end
@implement ColTable Measurements by data   # forwards to its field `data`
check("§5.2 own methods", colmean(Ramp([1.0, 3.0], 2), 2) == 4.0)
check("§5.3 forwarding with by", colmean(Measurements("m", [[1.0, 2.0]]), 1) == 1.5)
e = thrown(quote struct Nested; data::Measurements; end; @implement ColTable Nested by data end)
check("§5.3 forwarding does not chain: ImplementError", e isa ImplementError)
e = thrown(quote struct LRamp; n::Int; end; @implement ColTable LRamp project(r) = [collect(1.0:r.n)] end)
check("T-15 the internal project(t) = … form: a computed value is refused", e isa ImplementError && occursin("computes a value", msg(e)))

# §5.3
struct Halves; left::Vector{Vector{Float64}}; right::Vector{Vector{Float64}}; end
@implement ColTable Halves by right
check("§5.3 by right", colmean(Halves([[0.0]], [[6.0]]), 1) == 6.0)

# §5.4
struct Clock; time::Float64; data::Vector{Float64}; end
e = thrown(:(@implement Stepper Clock by data, t => time))
check("§5.4 `by data, t => time`", e === nothing && Base.invokelatest(elapsed, Clock(0.5, [1.0, 2.0])) == 1.0)
e === nothing || println("      error: ", first(msg(e), 300))

# §5.5
struct Grid; data::Matrix{Float64}; end
@implement (ColTable, RowTable) Grid by data
struct Grid2; data::Matrix{Float64}; end
@implement (ColTable, RowTable) Grid2 by data     # one field for both traits
check("§5.5 several traits by one field", overview(Grid([1.0 2.0; 3.0 4.0])) == (2.0, [1.0, 2.0]))
check("§5.5 one line", overview(Grid2([1.0 2.0; 3.0 4.0])) == (2.0, [1.0, 2.0]))
check("§3.6 a bundle as a bound", overview2(Grid([1.0 2.0; 3.0 4.0])) == (2.0, [1.0, 2.0]))
struct Sep; cols::Vector{Vector{Float64}}; rows::Matrix{Float64}; end
@implement ColTable Sep by cols
@implement RowTable Sep by rows
check("§5.5 each trait through its own field", overview(Sep([[1.0, 3.0]], [1.0 2.0; 3.0 4.0])) == (2.0, [1.0, 2.0]))

# §5.6
struct MyVec; v::Vector{Float32}; end
Columns.alen(m::MyVec) = length(m.v)
Columns.firstof(m::MyVec) = m.v[1]
@implement ArrayLike{Float32, 1} MyVec
check("§5.6 stated parameters", TraitWorld.param(ArrayLike, Val(:T), MyVec) === Float32 && TraitWorld.param(ArrayLike, Val(:N), MyVec) === 1)
struct StrVec; v::Vector{String}; end
Columns.alen(m::StrVec) = length(m.v)
Columns.firstof(m::StrVec) = m.v[1]
e = thrown(:(@implement ArrayLike{String, 1} StrVec))
check("T-1 a parameter's bound is not checked (T = String accepted for T <: Real)", e === nothing)

# §5.7 families
check("§5.7 a family by its own methods", d2(Columns.S{Int}(1, 2)) == 4)
check("§12.1 an existing function's methods declared", sizes(Float32[1, 2, 3]) == 3)

# §5.8 generic implementations, in the design's syntax
@trait_module module Gen
using TraitWorld
export Indexable, GTable, gn, gcol, gmean
@trait Indexable begin
    Base.length(r::Indexable)::Int
    Base.getindex(r::Indexable, i::Int)::eltype(Self)
end
@implement Indexable A where {A <: AbstractVector}
@trait GTable begin
    gn(t::GTable)::Int
    gcol(t::GTable, i::Int)::Vector{Float64}
end
@implement GTable R where {R: Indexable, eltype(R) == Vector{Float64}} begin
    gn(r) = length(r)
    gcol(r, i) = r[i]
end
@implement GTable Matrix{Float64} begin
    gn(r) = size(r, 2)
    gcol(r, i) = r[:, i]
end
gmean(t::GTable) = sum(gcol(t, 1)) / length(gcol(t, 1))
end
using .Gen
check("§5.8 a generic implementation", gmean([[1.0, 3.0]]) == 2.0)
check("§5.8 more specific beats generic", gmean([1.0 9.0; 3.0 9.0]) == 2.0)
check("§5.8 the condition refuses Vector{Int}", outcome(() -> gmean([1, 2])) isa MethodError)

# §5.9 dynamic operations (open)
struct Reversed; cols::Vector{Vector{Float64}}; end
@implement ColTable Reversed dynamic by cols begin
    ncols(r) = length(r)
    col(r, i) = r[end - i + 1]
end
check("§5.9 `dynamic by cols` is accepted", colmean(Reversed([[1.0, 2.0], [3.0, 5.0]]), 1) == 4.0)

# §5.10 redeclaration
e = thrown(quote
    @implement ColTable Ramp begin
        ncols(r) = r.n
        col(r, i) = r.base
    end
end)
check("§5.10 redeclaration is refused", e isa ImplementError && occursin("redeclar", msg(e)))

# §6.1
check("§6.1 an ordinary where variable on an ordinary argument", both_len([[1.0]], [1, 2]) == 3)
check("T-16 a shared where parameter in bounds: the method never applies", outcome(() -> kpair([1.0], [2.0])) isa MethodError)

# §6.5
check("§6.5 the AbstractMatrix method wins", describe([1.0 2.0]) == "a matrix")
check("§6.5 a table", describe([[1.0], [2.0]]) == "a table with 2 columns")
check("§6.5 the fallback", describe(42) == "something else")

# §7
m = Measurements("run", [[1.0, 2.0], [4.0]])
struct KMeas; label::String; data::Vector{Vector{Float64}}; end
@implement KTable KMeas by data
s = kscaled(KMeas("run", [[1.0, 2.0], [4.0]]), 2.0)
check("§7 Like{t}: the caller's type, the label kept", s isa KMeas && s.label == "run" && s.data == [[2.0, 4.0], [8.0]])
struct LBox; u::Vector{Float64}; label::String; end
@implement LRec LBox
b = shifted(LBox([1.0, 2.0], "b"))
check("§7 withfields", b isa LBox && b.u == [2.0, 3.0] && b.label == "b")

# §8
check("§8 colz defaults", colz(m, 1) == [-0.5, 0.5])
check("§8 a bounded keyword", colz(m, 1; baseline = Ramp([2.0, 4.0], 2)) == colz(m, 1; baseline = [[2.0, 4.0]]))
check("§8 tol = 1: TypeError", outcome(() -> colz(m, 1; tol = 1)) isa TypeError)
check("§8 baseline = 42: TraitBoundError", outcome(() -> colz(m, 1; baseline = 42)) isa TraitBoundError)
check("§8 positional default", colmean_or(m) == 1.5 && colmean_or(m, 2) == 4.0)
check("§8 a keyword default calling an operation", cm_all(m) == [1.5, 4.0])
check("§8 vararg of trait objects", ncols_sum(m, Ramp([1.0], 3), [[1.0]]) == 6 && ncols_sum() == 0)
check("§8 a vararg keyword passes on", kwrest(m; a = 1, b = 2) == (2, 2))

# §9
check("§9 colmap", colmap(x -> 2x, m, 1) == [2.0, 4.0])
check("§9 compiled_call", colmap(compiled_call(x -> 2x), m, 1) == [2.0, 4.0])
check("§9 dynamic_call", colsum(dynamic_call(x -> 2x), m, 1) == 6.0)
check("§9 abs2", colsum(abs2, m, 1) == 5.0)
check("§9 Callable{A, S, M}(f)", colmap(Callable{Tuple{Float64}, Float64, CompiledCall}(x -> x + 1), m, 1) == [2.0, 3.0])
check("§9 several signatures", both(x -> x + one(x), 1.5, 2) == (2.5, 3))
check("§9 a result of another type: TypeError", outcome(() -> colmap(x -> 1, m, 1)) isa TypeError)
@trait_module module CB
using TraitWorld
export FunctionCallback, fire, apply_open
struct FunctionCallback
    cond::DynamicFn{Tuple{Vector{Float64}, Float64}, Bool}
end
fire(cb::FunctionCallback, u::Vector{Float64}) = cb.cond(u, 0.0)
apply_open(f::Callable{Tuple{Float64}, S}, x::Float64) where {S} = f(x)    # planned: an open result type
end
using .CB
callback(f) = FunctionCallback(dynamic_fn(Tuple{Vector{Float64}, Float64}, Bool, f))   # in plain code
check("§9 a stored DynamicFn", fire(callback((u, t) -> u[1] > t), [1.0]) === true)
check("T-18 an open Callable result type is no bound: MethodError", outcome(() -> apply_open(x -> 2x, 1.0)) isa MethodError)

# §10
@trait_module module DynSolv
using TraitWorld
export Model, rhs!, Hook, fire!, State, start, step!, keepwrong
@trait Model begin
    rhs!(m::Model, du::Vector{Float64}, u::Vector{Float64}, t::Float64)::Nothing
end
@trait Hook begin
    fire!(h::Hook, u::Vector{Float64}, t::Float64)::Bool
end
mutable struct State                 # in a trait module
    const u::Vector{Float64}
    t::Float64
    model::Model                     # means Dynamic{Model}
    hooks::Vector{Hook}              # means Vector{Dynamic{Hook}}
end
start(m::Model, u0::Vector{Float64}) = State(copy(u0), 0.0, Dynamic{Model}(m), Dynamic{Hook}[])
function step!(s::State, dt::Float64)
    du = similar(s.u)
    rhs!(s.model, du, s.u, s.t)
    s.u .+= dt .* du
    s.t += dt
    return count(h -> fire!(h, s.u, s.t), s.hooks)
end
keepwrong(h::Hook) = Dynamic{Model}(h)
end
using .DynSolv
struct Decay; k::Float64; end
DynSolv.rhs!(m::Decay, du, u, t) = (du .= -m.k .* u; nothing)
@implement Model Decay
struct Below; level::Float64; end
DynSolv.fire!(h::Below, u, t) = u[1] < h.level
@implement Hook Below
struct Always; end
DynSolv.fire!(::Always, u, t) = true
@implement Hook Always
st = start(Decay(1.0), [1.0])
append!(st.hooks, Dynamic{Hook}[Dynamic{Hook}(Below(0.95)), Dynamic{Hook}(Always())])   # in plain code
check("§10 fields mean Dynamic", fieldtype(DynSolv.State, :hooks) === Vector{Dynamic{DynSolv.Hook}})
check("§10 step! over a Dynamic model and hooks", step!(st, 0.1) == 2 && st.u ≈ [0.9])
check("§10 a trait object of another trait: ArgumentError", outcome(() -> keepwrong(Always())) isa ArgumentError)
check("§10 equality", st.hooks[1] == st.hooks[1] && st.hooks[1] != st.hooks[2])
println("      print: ", sprint(show, st.model))

# §16
check("§16 conforms", conforms(Vector{Float64}, KVec) && conforms(Vector{Float64}, KVec{Float64}) && !conforms(Vector{Int}, KVec{Float64}))
check("§16 x isa X is false today", !(Ramp([1.0], 1) isa ColTable))

# §11
@trait_module module BadDef
using TraitWorld, ..Columns
spread(t::ColTable) = size(t)    # `size` is not an operation of ColTable
leak(t::ColTable) = typeof(t)    # code must not depend on the user's type
end
e = try check_definitions(BadDef); nothing; catch err; err; end
check("§11 check_definitions raises TraitUseError listing both", e isa TraitUseError && occursin("spread", join(e.problems)) && occursin("leak", join(e.problems)))
check("§11 check_definitions of a clean module is empty", isempty(check_definitions(Columns)))

# §15
module VMain
using ..Columns
using Main: Measurements, Ramp
function main(args::Vector{String})
    t = isempty(args) ? Ramp([1.0, 2.0], 2) : Measurements("m", [[1.0, 2.0]])
    return colmean(t, 1)::Float64
end
end
VMain.main(String[]); VMain.main(["m"])
check("§15 verify_main", isclosed(verify_main(VMain.main, (Vector{String},))))

# T-2: a trait parameter in a default's body (planned: in scope)
e = thrown(quote
    @trait_module module DefParam
    using TraitWorld
    export PM, pfirst, pstate, usestate
    @trait PM{T} begin
        T = eltype(Self)
        pfirst(m::PM{T})::T
        pstate(m::PM{T}, u0::Vector{Float64})::Vector{T} = Vector{T}(u0)
    end
    @implement PM A where {A <: Vector{Float64}} begin
        pfirst(m) = m[1]
    end
    usestate(m::PM) = pstate(m, [1.0])
    end
end)
r = e === nothing ? outcome(() -> Main.DefParam.usestate([2.0])) : e
check("T-2 a trait parameter in a default's body: an error", r isa Exception)
println("      outcome: ", r isa Exception ? first(msg(r), 200) : r)

summary()
