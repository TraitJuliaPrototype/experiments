# E-145: what should follow the `Dynamic` split. One operation (`area`, one multiply) on 64 types;
# a sum over 1000 values of a type mix, per element. Every option is emulated in plain Julia, beside
# TraitWorld's own `Dynamic` (the split over the first four declared, then Julia's dynamic dispatch):
#   any      plain Julia: `area(x)` over a Vector{Any} (dispatch only)
#   tw       TraitWorld: an operation on Vector{Dynamic{S}} (split 4 + dynamic dispatch, as built)
#   s4+dyn   emulated: split over the first four + `area(x)` dispatched (should match tw)
#   sall     split over all n types of the mix + dispatch (the longer split)
#   s4+pic   split 4 + a per-site cache of 8 (type, pointer) pairs, refilled round robin from the table
#   s4+hash  split 4 + one table per trait, type -> pointer (open addressing on the type's address)
#   s4+wit   split 4 + a witness carried in the value: (object, witness), the witness a record of
#            `:caller_world` pointers made once per type (Rust's vtable, Swift's witness table, Go's itab)
#   s4+witp  the same with plain `cfunction` pointers (latest world): the cost of the world check
#   s4+idx   split 4 + an index carried in the value into the trait's vector of pointers
#   wit      the witness only, no split (Rust's `dyn`, Swift's `any`)
#   hot+wit  a split over the (up to 8) types the mix holds most often, then the witness: the code a
#            recompilation with the observed types would produce
# Pointers take the object boxed (`Any`) and return a Float64, with a world check per call for
# `:caller_world` (julia-1.13 piece 18). Also: wrapping cost, compile time and size of longer splits.
#
#     ./run.sh product --project=. e145.jl
include("common.jl")
using TraitWorld, Random, Printf, InteractiveUtils
header("e145")
const NT = 64
const N = 1000

# --- 64 types, one method each; and a trait with 64 implementations (distinct lines: declaration order)
let io = IOBuffer()
    for i in 1:NT
        println(io, "struct T$i; a::Float64; end")
        println(io, "area(x::T$i) = $(Float64(i)) * x.a")
    end
    include_string(Main, String(take!(io)), "e145_types.jl")
end
const TYPES = Any[getfield(Main, Symbol(:T, i)) for i in 1:NT]
@trait_module module FB
using TraitWorld
export S, sarea, tot
@trait S begin
    sarea(s::S)::Float64
end
function tot(v::Vector{Dynamic{S}})
    s = 0.0
    for d in v
        s += sarea(d)
    end
    return s
end
end
let io = IOBuffer()
    for i in 1:NT
        println(io, "TraitWorld.@implement FB.S T$i begin sarea(s) = $(Float64(i)) * s.a end")
    end
    include_string(Main, String(take!(io)), "e145_impls.jl")
end
println("TraitWorld's split covers: ", join(string.(Base.Compiler.dynamic_candidates(TraitWorld._family(FB.S))), ", "))

# --- pointers: one callable per type, behind a `cfunction` taking the boxed object
struct AreaOf{T} end
(::AreaOf{T})(@nospecialize(x)) where {T} = area(x::T)
@generated cw_ptr(::Type{T}) where {T} = Expr(:cfunction, Ptr{Cvoid}, QuoteNode(AreaOf{T}()), Float64, :(Core.svec(Any)), QuoteNode(:caller_world))
@generated plain_ptr(::Type{T}) where {T} = Expr(:cfunction, Ptr{Cvoid}, QuoteNode(AreaOf{T}()), Float64, :(Core.svec(Any)), QuoteNode(:ccall))
const SESSION = Ref(UInt(1))
mutable struct Wit
    fp::Ptr{Cvoid}
    session::UInt
end
"One table per trait: type -> (pointer, witness), open addressing on the type's address."
mutable struct TypeTable
    keys::Vector{Any}
    fps::Vector{Ptr{Cvoid}}
    wits::Vector{Any}
    pwits::Vector{Any}
    mask::Int
end
@inline tslot(@nospecialize(T), mask) = (reinterpret(Int, pointer_from_objref(T)) >> 4) & mask
@inline function tindex(tt::TypeTable, @nospecialize(T))
    i = tslot(T, tt.mask)
    ks = tt.keys
    while true
        k = @inbounds ks[i + 1]
        k === T && return i + 1
        k === nothing && return 0
        i = (i + 1) & tt.mask
    end
end
const TT = TypeTable(fill!(Vector{Any}(undef, 256), nothing), fill(C_NULL, 256), Vector{Any}(undef, 256), Vector{Any}(undef, 256), 255)
const FPS = Vector{Ptr{Cvoid}}(undef, NT)          # the trait's vector, by implementation index
for (k, T) in enumerate(TYPES)
    i = tslot(T, TT.mask)
    while TT.keys[i + 1] !== nothing; i = (i + 1) & TT.mask; end
    fp = Base.invokelatest(cw_ptr, T)
    TT.keys[i + 1] = T; TT.fps[i + 1] = fp
    TT.wits[i + 1] = Wit(fp, SESSION[]); TT.pwits[i + 1] = Wit(Base.invokelatest(plain_ptr, T), SESSION[])
    FPS[k] = fp
end
const IDX = IdDict{Any,Int}(T => k for (k, T) in enumerate(TYPES))

# --- the values
struct Dyn; t::Any; end                    # TraitWorld's layout: the object
struct DynW; t::Any; w::Wit; end           # the object and its witness
struct DynI; t::Any; k::Int; end           # the object and its implementation's index
mkw(@nospecialize(x)) = DynW(x, TT.wits[tindex(TT, typeof(x))]::Wit)
mkwp(@nospecialize(x)) = DynW(x, TT.pwits[tindex(TT, typeof(x))]::Wit)
mki(@nospecialize(x)) = DynI(x, IDX[typeof(x)])

# --- the split, and what follows it
"""
A split over the types `Ts`, then `fb(x)`: an ordinary function made per list, `@inline` (a generated
function is not expanded at an `Any` argument, so it would stay a dynamic call).
"""
function make_split(Ts)
    ex = :(fb(x))
    for T in reverse(Ts)
        ex = :(x isa $T ? area(x::$T) : $ex)
    end
    name = Symbol(:split_, join(map(T -> string(nameof(T)), Ts), :_))
    isdefined(Main, name) || Core.eval(Main, :(@inline $name(x, fb) = $ex))
    return Base.invokelatest(getglobal, Main, name)
end
struct FbDyn end
@inline (::FbDyn)(x) = area(x)::Float64
struct FbHash end
@inline (::FbHash)(x) = ccall(@inbounds(TT.fps[tindex(TT, typeof(x))]), Float64, (Any,), x)
mutable struct PIC
    types::Vector{Any}
    fps::Vector{Ptr{Cvoid}}
    next::Int
end
PIC() = PIC(Any[nothing for _ in 1:8], fill(C_NULL, 8), 1)
const SITE = PIC()
struct FbPIC end
@inline function (::FbPIC)(x)
    T = typeof(x)
    ts = SITE.types
    for i in 1:8
        @inbounds ts[i] === T && return ccall(@inbounds(SITE.fps[i]), Float64, (Any,), x)
    end
    return picmiss(SITE, x)
end
@noinline function picmiss(p::PIC, @nospecialize(x))
    fp = @inbounds TT.fps[tindex(TT, typeof(x))]
    i = p.next
    p.types[i] = typeof(x); p.fps[i] = fp
    p.next = i == 8 ? 1 : i + 1
    return ccall(fp, Float64, (Any,), x)
end
@noinline refresh(w::Wit) = (w.session = SESSION[]; w)
struct FbWit; w::Wit; end
@inline function (f::FbWit)(x)
    w = f.w
    w.session === SESSION[] || refresh(w)
    return ccall(w.fp, Float64, (Any,), x)
end
struct FbIdx; k::Int; end
@inline (f::FbIdx)(x) = ccall(@inbounds(FPS[f.k]), Float64, (Any,), x)

const C4 = make_split([T1, T2, T3, T4])
s_any(v::Vector{Any}) = (s = 0.0; for x in v; s += area(x)::Float64; end; s)
s_s4dyn(v::Vector{Dyn}) = (s = 0.0; for d in v; s += C4(d.t, FbDyn()); end; s)
s_sall(v::Vector{Dyn}, sp::F) where {F} = (s = 0.0; for d in v; s += sp(d.t, FbDyn()); end; s)
s_s4pic(v::Vector{Dyn}) = (s = 0.0; for d in v; s += C4(d.t, FbPIC()); end; s)
s_s4hash(v::Vector{Dyn}) = (s = 0.0; for d in v; s += C4(d.t, FbHash()); end; s)
s_s4wit(v::Vector{DynW}) = (s = 0.0; for d in v; s += C4(d.t, FbWit(d.w)); end; s)
s_s4idx(v::Vector{DynI}) = (s = 0.0; for d in v; s += C4(d.t, FbIdx(d.k)); end; s)
s_wit(v::Vector{DynW}) = (s = 0.0; for d in v; s += FbWit(d.w)(d.t); end; s)
s_hot(v::Vector{DynW}, sp::F) where {F} = (s = 0.0; for d in v; s += sp(d.t, FbWit(d.w)); end; s)

# --- the mixes
rng = Xoshiro(145)
mixes = Any[]
for n in (5, 8, 16, 64)
    push!(mixes, ("uniform n=$n", n, Any[TYPES[rand(rng, 1:n)](1.0) for _ in 1:N]))
end
for n in (8, 64)       # 90 % one type outside the split (T5), the rest uniform over n
    push!(mixes, ("skewed n=$n", n, Any[rand(rng) < 0.9 ? T5(1.0) : TYPES[rand(rng, 1:n)](1.0) for _ in 1:N]))
end
push!(mixes, ("cyclic n=64", 64, Any[TYPES[mod1(i, 64)](1.0) for i in 1:N]))
push!(mixes, ("phases n=64", 64, Any[i <= N ÷ 2 ? TYPES[rand(rng, 5:12)](1.0) : TYPES[rand(rng, 13:20)](1.0) for i in 1:N]))

# the splits each mix needs, made before the loop that calls them (a later world)
splits = map(mixes) do (name, n, va)
    present = unique(typeof.(va))
    counts = Dict(T => count(x -> typeof(x) === T, va) for T in present)
    call = sort(present; by = T -> findfirst(y -> y === T, TYPES))
    hot = first(sort(present; by = T -> -counts[T]), min(8, length(present)))
    (make_split(call), length(call), make_split(hot), length(hot))
end
const SPLIT_N = Dict(n => make_split(reverse(TYPES[1:n])) for n in (4, 8, 16, 32, 64))   # lists not used above: compiled fresh

for ((name, n, va), (call, ncall, hot, nhot)) in zip(mixes, splits)
    vd = Dyn[Dyn(x) for x in va]; vw = DynW[mkw(x) for x in va]; vp = DynW[mkwp(x) for x in va]; vi = DynI[mki(x) for x in va]
    vt = Dynamic{FB.S}[Dynamic{FB.S}(x) for x in va]
    present = unique(typeof.(va))
    r = s_any(va)
    @assert r ≈ FB.tot(vt) ≈ s_s4dyn(vd) ≈ s_sall(vd, call) ≈ s_s4pic(vd) ≈ s_s4hash(vd) ≈ s_s4wit(vw) ≈ s_s4wit(vp) ≈ s_s4idx(vi) ≈ s_wit(vw) ≈ s_hot(vw, hot)
    println("-- ", name, " (", length(present), " types present)")
    @row "any: area(x) over Vector{Any}" name N s_any($va)
    @row "tw: TraitWorld Dynamic, split 4 + dispatch" name N FB.tot($vt)
    @row "s4+dyn: split 4 + dispatch (emulated)" name N s_s4dyn($vd)
    @row "sall: split over all $ncall present + dispatch" name N s_sall($vd, $call)
    @row "s4+pic: split 4 + per-site cache of 8" name N s_s4pic($vd)
    @row "s4+hash: split 4 + table per trait (by type)" name N s_s4hash($vd)
    @row "s4+wit: split 4 + carried witness (caller_world)" name N s_s4wit($vw)
    @row "s4+witp: split 4 + carried witness (plain cfunction)" name N s_s4wit($vp)
    @row "s4+idx: split 4 + carried index (caller_world)" name N s_s4idx($vi)
    @row "wit: carried witness only, no split" name N s_wit($vw)
    @row "hot+wit: split over $nhot most frequent + witness" name N s_hot($vw, $hot)
end

# --- making the values from a Vector{Any}: the lookup moves here for a carried witness
va = mixes[4][3]
println("-- making values from a Vector{Any} (uniform n=64)")
@row "Dyn(x) (TraitWorld's layout, emulated)" "make" N Dyn[Dyn(x) for x in $va]
@row "DynW: witness looked up per value" "make" N DynW[mkw(x) for x in $va]
@row "TraitWorld collect(DynamicItems{S}(v))" "make" N collect(DynamicItems{FB.S}($va))

# --- the longer split: compile time and code size per n (fresh specializations)
println("-- the longer split: compile time and native code size of the loop")
for n in (4, 8, 16, 32, 64)
    sp = SPLIT_N[n]
    v = Dyn[Dyn(T(1.0)) for T in TYPES[1:n]]
    t = @elapsed s_sall(v, sp)
    sz = length(sprint(io -> code_native(io, s_sall, (Vector{Dyn}, typeof(sp)); debuginfo = :none)))
    @printf("%-8s %-12s split over %2d types: first call %7.1f ms, native code %7d bytes of text\n", SETTING, "compile", n, 1000t, sz)
end
println("== done  load ", join(loadavg(), " "))
