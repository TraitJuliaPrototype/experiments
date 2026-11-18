# E-145, second run: the same options with 64 types that differ in layout and in their operations'
# code (eight shapes of struct and formula, a constant per type), so a split cannot fold into a
# table of constants; and a second operation of more work (`work`, a short loop with sqrt).
#
#     ./run.sh product --project=. e145b.jl
include("common.jl")
using TraitWorld, Random, Printf, InteractiveUtils
header("e145b"); println("elements per mix: ", parse(Int, get(ENV, "E145_N", "1000")))
const NT = 64
const N = parse(Int, get(ENV, "E145_N", "1000"))   # elements per mix; 131072 defeats branch predictors that learn a repeated sequence
const SHAPES = [   # fields; area's formula; work's formula (j = 1:8), in the fields and the constant c
    ("a::Float64", "c * x.a", "sqrt(x.a + j) * c"),
    ("a::Float64; b::Float64", "c * x.a * x.b", "sqrt(x.a * j + x.b) + c"),
    ("n::Int; a::Float64", "x.a + c * x.n", "sqrt(abs(x.a - j)) * x.n + c"),
    ("a::Float64; b::Float64; d::Float64", "c * (x.a + x.b + x.d) / 3", "sqrt(x.a + x.b * j) - x.d * c"),
    ("a::Float32; b::Float64", "Float64(x.a) * c - x.b", "sqrt(Float64(x.a) + j) * x.b + c"),
    ("k::Int32; a::Float64", "x.a * x.a * c + x.k", "sqrt(x.a * x.a + j) + c * x.k"),
    ("a::Float64; flag::Bool", "x.flag ? c * x.a : -x.a", "x.flag ? sqrt(x.a + j) : c * j"),
    ("p::Tuple{Float64,Float64}", "c * (x.p[1] - x.p[2])", "sqrt(x.p[1] * j) + x.p[2] * c"),
]
const CTOR = ["T(a)", "T(a, 2a)", "T(3, a)", "T(a, 2a, 3a)", "T(Float32(a), a)", "T(Int32(2), a)", "T(a, true)", "T((a, 2a))"]
let io = IOBuffer(), imp = IOBuffer()
    for i in 1:NT
        f, ar, wk = SHAPES[mod1(i, 8)]
        c = 1.0 + i / 64
        println(io, "struct T$i; $f; end")
        println(io, "mk(::Type{T$i}, a) = $(replace(CTOR[mod1(i, 8)], "T(" => "T$i("))")
        println(io, "area(x::T$i) = (c = $c; $ar)")
        println(io, "work(x::T$i) = (c = $c; s = 0.0; for j in 1:8; s += $wk; end; s)")
        println(imp, "TraitWorld.@implement FB.S T$i begin sarea(x) = (c = $c; $ar); swork(x) = (c = $c; s = 0.0; for j in 1:8; s += $wk; end; s) end")
    end
    include_string(Main, String(take!(io)), joinpath(@__DIR__, "e145b_types.jl"))
    global IMPLS = String(take!(imp))
end
const TYPES = Any[getfield(Main, Symbol(:T, i)) for i in 1:NT]
@trait_module module FB
using TraitWorld
export S, sarea, swork, tota, totw
@trait S begin
    sarea(s::S)::Float64
    swork(s::S)::Float64
end
tota(v::Vector{Dynamic{S}}) = (s = 0.0; for d in v; s += sarea(d); end; s)
totw(v::Vector{Dynamic{S}}) = (s = 0.0; for d in v; s += swork(d); end; s)
end
include_string(Main, IMPLS, joinpath(@__DIR__, "e145b_impls.jl"))
println("TraitWorld's split covers: ", join(string.(Base.Compiler.dynamic_candidates(TraitWorld._family(FB.S))), ", "))

# --- pointers per (operation, type), behind `:caller_world` cfunctions taking the boxed object
struct OpOf{F,T} end
(::OpOf{F,T})(@nospecialize(x)) where {F,T} = F.instance(x::T)
@generated cw_ptr(::Type{F}, ::Type{T}) where {F,T} = Expr(:cfunction, Ptr{Cvoid}, QuoteNode(OpOf{F,T}()), Float64, :(Core.svec(Any)), QuoteNode(:caller_world))
const SESSION = Ref(UInt(1))
"A witness: the trait's operations for one type (Rust's vtable, Swift's witness table)."
mutable struct Wit
    area::Ptr{Cvoid}
    work::Ptr{Cvoid}
    session::UInt
end
mutable struct TypeTable
    keys::Vector{Any}
    wits::Vector{Any}
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
const TT = TypeTable(fill!(Vector{Any}(undef, 256), nothing), Vector{Any}(undef, 256), 255)
for T in TYPES
    i = tslot(T, TT.mask)
    while TT.keys[i + 1] !== nothing; i = (i + 1) & TT.mask; end
    TT.keys[i + 1] = T
    TT.wits[i + 1] = Wit(Base.invokelatest(cw_ptr, typeof(area), T), Base.invokelatest(cw_ptr, typeof(work), T), SESSION[])
end
struct Dyn; t::Any; end
struct DynW; t::Any; w::Wit; end
mkw(@nospecialize(x)) = DynW(x, TT.wits[tindex(TT, typeof(x))]::Wit)

function make_split(op, Ts)
    ex = :(fb(x))
    for T in reverse(Ts)
        ex = :(x isa $T ? $op(x::$T) : $ex)
    end
    name = Symbol(:split_, op, :_, join(map(T -> string(nameof(T)), Ts), :_))
    isdefined(Main, name) || Core.eval(Main, :(@inline $name(x, fb) = $ex))
    return Base.invokelatest(getglobal, Main, name)
end
struct FbDyn{F} end
@inline (::FbDyn{F})(x) where {F} = F.instance(x)::Float64
@noinline refresh(w::Wit) = (w.session = SESSION[]; w)
struct FbHash{K} end                                   # K: the operation's field in the witness
@inline (::FbHash{K})(x) where {K} = ccall(getfield((@inbounds TT.wits[tindex(TT, typeof(x))])::Wit, K), Float64, (Any,), x)
struct FbWit{K}; w::Wit; end
@inline function (f::FbWit{K})(x) where {K}
    w = f.w
    w.session === SESSION[] || refresh(w)
    return ccall(getfield(w, K), Float64, (Any,), x)
end

s_any(v::Vector{Any}, op::F) where {F} = (s = 0.0; for x in v; s += op(x)::Float64; end; s)
s_dyn(v::Vector{Dyn}, sp::P, ::Val{K}, op::F) where {P,K,F} = (s = 0.0; for d in v; s += sp(d.t, FbDyn{F}()); end; s)
s_hash(v::Vector{Dyn}, sp::P, ::Val{K}) where {P,K} = (s = 0.0; for d in v; s += sp(d.t, FbHash{K}()); end; s)
s_wit(v::Vector{DynW}, sp::P, ::Val{K}) where {P,K} = (s = 0.0; for d in v; s += sp(d.t, FbWit{K}(d.w)); end; s)
s_witonly(v::Vector{DynW}, ::Val{K}) where {K} = (s = 0.0; for d in v; s += FbWit{K}(d.w)(d.t); end; s)

rng = Xoshiro(145)
mixes = Any[]
for n in (5, 8, 16, 64)
    push!(mixes, ("uniform n=$n", Any[mk(TYPES[rand(rng, 1:n)], 1.0) for _ in 1:N]))
end
push!(mixes, ("skewed n=64", Any[rand(rng) < 0.9 ? mk(T5, 1.0) : mk(TYPES[rand(rng, 1:64)], 1.0) for _ in 1:N]))
push!(mixes, ("cyclic n=64", Any[mk(TYPES[mod1(i, 64)], 1.0) for i in 1:N]))
push!(mixes, ("phases n=64", Any[i <= N ÷ 2 ? mk(TYPES[rand(rng, 5:12)], 1.0) : mk(TYPES[rand(rng, 13:20)], 1.0) for i in 1:N]))
const OPS = ((area, :area, FB.tota), (work, :work, FB.totw))
splits = map(mixes) do (name, va)
    present = unique(typeof.(va))
    counts = Dict(T => count(x -> typeof(x) === T, va) for T in present)
    call = sort(present; by = T -> findfirst(y -> y === T, TYPES))
    hot = first(sort(present; by = T -> -counts[T]), min(8, length(present)))
    [(make_split(op, TYPES[1:4]), make_split(op, call), make_split(op, hot), length(call), length(hot)) for (op, _, _) in OPS]
end
const SPLIT_N = Dict(n => make_split(area, reverse(TYPES[1:n])) for n in (4, 8, 16, 32, 64))

for ((name, va), sps) in zip(mixes, splits)
    vd = Dyn[Dyn(x) for x in va]; vw = DynW[mkw(x) for x in va]
    vt = Dynamic{FB.S}[Dynamic{FB.S}(x) for x in va]
    println("-- ", name, " (", length(unique(typeof.(va))), " types present)")
    for ((op, k, tot), (s4, sall, hot, ncall, nhot)) in zip(OPS, sps)
        K = Val(k)
        r = s_any(va, op)
        @assert r ≈ tot(vt) ≈ s_dyn(vd, s4, K, op) ≈ s_dyn(vd, sall, K, op) ≈ s_hash(vd, s4, K) ≈ s_wit(vw, s4, K) ≈ s_witonly(vw, K) ≈ s_wit(vw, hot, K)
        lab = string(k)
        @row "$lab any: Julia dispatch over Vector{Any}" name N s_any($va, $op)
        @row "$lab tw: TraitWorld Dynamic (split 4 + dispatch)" name N $tot($vt)
        @row "$lab s4+dyn: split 4 + dispatch (emulated)" name N s_dyn($vd, $s4, $K, $op)
        @row "$lab sall: split over all $ncall present + dispatch" name N s_dyn($vd, $sall, $K, $op)
        @row "$lab s4+hash: split 4 + table per trait (by type)" name N s_hash($vd, $s4, $K)
        @row "$lab s4+wit: split 4 + carried witness" name N s_wit($vw, $s4, $K)
        @row "$lab wit: carried witness only, no split" name N s_witonly($vw, $K)
        @row "$lab hot+wit: split over $nhot most frequent + witness" name N s_wit($vw, $hot, $K)
    end
end
println("-- the longer split (area): compile time and native code size of the loop")
for n in (4, 8, 16, 32, 64)
    sp = SPLIT_N[n]
    v = Dyn[Dyn(mk(T, 1.0)) for T in TYPES[1:n]]
    t = @elapsed s_dyn(v, sp, Val(:area), area)
    sz = length(sprint(io -> code_native(io, s_dyn, (Vector{Dyn}, typeof(sp), Val{:area}, typeof(area)); debuginfo = :none)))
    @printf("%-8s %-12s split over %2d types: first call %7.1f ms, native code %7d bytes of text\n", SETTING, "compile", n, 1000t, sz)
end
println("== done  load ", join(loadavg(), " "))
