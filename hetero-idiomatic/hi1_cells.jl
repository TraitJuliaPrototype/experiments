# E-134: the review's loops on heterogeneous data (hc1, hc4, hc7) written three ways, run in one
# process: plain Julia (the stock idiom, in Main), interop (a trait module calling Base's generic
# algorithms on the user's containers, as hc7 did), and idiomatic trait code (functions bounded by
# BaseTraits' collection traits, items `Dynamic{Cell}`), called with the user's `Vector{Any}` /
# `Dict{String,Any}` directly ("direct": the entry translates it into the view), with the view written
# out ("view": `DynamicItems{Cell}(v)`), and over a copy into `Vector{Dynamic{Cell}}`.
# Data as in hc1/hc7: 1000 elements, Ints and Strings shuffled; a Dict{String,Any} of 1000 entries,
# odd keys Int values, even keys String values.
#
#     ./run.sh product --project=. hi1_cells.jl      (and ./run.sh all …)
include("common.jl")
using Random, TraitWorld
header("hi1_cells")
Random.seed!(1)
const N = 1000
const anys = shuffle!([rand(1:N, N); [randstring(rand(1:30)) for _ in 1:N]])[1:N]::Vector{Any}
const dd = Dict{String,Any}(string(i) => (isodd(i) ? i : string(i)) for i in 1:N)
const ks = collect(keys(dd))
const reals = Real[isodd(i) ? i : Float64(i) for i in 1:N]
const anyints = Any[i for i in 1:N]

# --- idiomatic trait code ------------------------------------------------------------------------
@trait_module module CellCore
using TraitWorld
export Cell, isnum, weight, Num, value,
       keepnums!, keepwhere!, countnums, countwhere, countwhere_c, countvals, sumlookup, total
"A cell of a table read from outside: a number or a text."
@trait Cell begin
    isnum(c::Cell)::Bool
    weight(c::Cell)::Int
end
@implement Cell Int begin
    isnum(c) = true
    weight(c) = c
end
@implement Cell String begin
    isnum(c) = false
    weight(c) = length(c)
end
"A number seen as a Float64."
@trait Num begin
    value(x::Num)::Float64
end
@implement Num Int begin value(x) = Float64(x) end
@implement Num Float64 begin value(x) = x end

# filter!: keep the numbers, in place (BaseTraits' retain!, with a trait operation as the predicate)
keepnums!(xs::(MutableIndexable{Cell}, Resizable)) = retain!(isnum, xs)
# the same with a predicate from the caller, at a declared signature (both modes)
keepwhere!(f::Callable{Tuple{Dynamic{Cell}}, Bool}, xs::(MutableIndexable{Cell}, Resizable)) = retain!(f, xs)
# count with an operation on each item (hc7's "isa on each element")
countnums(xs::Iterable{Cell}) = (n = 0; for c in xs; n += isnum(c); end; n)
# count with a predicate from the caller (hc7's Callable{Tuple{Any}, Bool})
countwhere(f::Callable{Tuple{Dynamic{Cell}}, Bool}, xs::Iterable{Cell}) = (n = 0; for c in xs; n += f(c); end; n)
countwhere_c(f::Callable{Tuple{Dynamic{Cell}}, Bool, CompiledCall}, xs::Iterable{Cell}) = (n = 0; for c in xs; n += f(c); end; n)
# a Dict's pairs (hc7's `for (k, v) in d::Dict{String,Any}`)
countvals(d::Iterable{Pair{String, Cell}}) = (n = 0; for (k, c) in d; n += isnum(c); end; n)
# keyed access
sumlookup(d::Keyed{String, Cell}, ks::Vector{String}) = (s = 0; for k in ks; s += weight(d[k]); end; s)
# hc4's sums: numbers of mixed types
total(xs::Iterable{Num}) = (s = 0.0; for x in xs; s += value(x); end; s)
end
using .CellCore

# --- interop: trait code calling Base on the user's containers (hc7's module, and hc4's loops) ------
@trait_module module Interop
using TraitWorld
export tfilt!, tcount, tcount_cb, tdictloop, tlookup, tsumany, tsumreal
tfilt!(v::Vector{Any}) = filter!(x -> isa(x, Int), v)
tcount(v::Vector{Any}) = (n = 0; for x in v; n += isa(x, Int); end; n)
tcount_cb(f::Callable{Tuple{Any}, Bool}, v::Vector{Any}) = (n = 0; for x in v; n += f(x); end; n)
tdictloop(d::Dict{String,Any}) = (n = 0; for (k, v) in d; n += v isa Int; end; n)
tlookup(d::Dict{String,Any}, ks::Vector{String}) = (s = 0; for k in ks; v = d[k]; s += v isa Int ? v : length(v::String); end; s)
tsumany(v::Vector{Any}) = (s = 0.0; for x in v; s += x; end; s)
tsumreal(v::Vector{Real}) = (s = 0.0; for x in v; s += Float64(x); end; s)
end
using .Interop

# --- plain Julia, the stock idiom ---------------------------------------------------------------------
pfilt!(v::Vector{Any}) = filter!(x -> isa(x, Int), v)
pcount(v::Vector{Any}) = (n = 0; for x in v; n += isa(x, Int); end; n)
pcount_cb(f, v::Vector{Any}) = (n = 0; for x in v; n += f(x)::Bool; end; n)
pdictloop(d::Dict{String,Any}) = (n = 0; for (k, v) in d; n += v isa Int; end; n)
plookup(d::Dict{String,Any}, ks::Vector{String}) = (s = 0; for k in ks; v = d[k]; s += v isa Int ? v : length(v::String); end; s)
psumany(v::Vector{Any}) = (s = 0.0; for x in v; s += x; end; s)
psumreal(v::Vector{Real}) = (s = 0.0; for x in v; s += Float64(x); end; s)

# --- the same answers ---------------------------------------------------------------------------------
const w = collect(DynamicItems{Cell}(anys))              # the copy, made through the view
const wd = Dict{String, Dynamic{Cell}}(k => Dynamic{Cell}(v) for (k, v) in dd)
const pred = c -> isnum(c)
const pred_plain = x -> isa(x, Int)
const h600 = 600
const wn = collect(DynamicItems{Num}(reals))
let a = copy(anys), b = copy(anys), c = copy(w)
    pfilt!(a); keepnums!(DynamicItems{Cell}(b)); keepnums!(c)
    @assert a == b && length(c) == length(a) && Interop.tfilt!(copy(anys)) == a
end
@assert countnums(DynamicItems{Cell}(anys)) == countnums(anys) == countnums(w) == pcount(anys) == tcount(anys)
@assert countvals(dd) == pdictloop(dd) && sumlookup(dd, ks) == plookup(dd, ks) && total(reals) == psumreal(reals)
let a = copy(anys); keepnums!(a); @assert a == filter(x -> isa(x, Int), anys); end      # the user's vector, written
@assert countwhere(pred, DynamicItems{Cell}(anys)) == pcount(anys)
@assert countvals(DynamicValues{Cell}(dd)) == countvals(wd) == pdictloop(dd) == tdictloop(dd)
@assert sumlookup(DynamicValues{Cell}(dd), ks) == plookup(dd, ks) == tlookup(dd, ks)
@assert total(DynamicItems{Num}(reals)) == psumreal(reals) && total(DynamicItems{Num}(anyints)) == psumany(anyints)

# --- the table ------------------------------------------------------------------------------------------
println("-- W1 filter!: keep the Ints of a Vector{Any}")
@row "Base.filter!(x -> isa(x, Int), v)" "plain" N pfilt!(d) (d = copy(anys))
@row "Base.filter! from a trait module (hc7)" "interop" N tfilt!(d) (d = copy(anys))
@row "retain!(isnum, ·) over DynamicItems{Cell}(v)" "view" N keepnums!(d) (d = DynamicItems{Cell}(copy(anys)))
@row "retain!(isnum, v), v the user's Vector{Any}" "direct" N keepnums!(d) (d = copy(anys))
@row "retain!(isnum, ·) over Vector{Dynamic{Cell}}" "copy" N keepnums!(d) (d = copy(w))
@row "retain!(f::Callable{…}) over the view, DynamicCall" "view" N keepwhere!(pred, d) (d = DynamicItems{Cell}(copy(anys)))
@row "retain!(f::Callable{…}) over the view, compiled_call" "view" N keepwhere!(compiled_call(pred), d) (d = DynamicItems{Cell}(copy(anys)))
@row "retain!(compiled_call(f), v), v the user's vector" "direct" N keepwhere!(compiled_call(pred), d) (d = copy(anys))
println("-- W2 count, an operation on each element")
@row "n += isa(x, Int)" "plain" N pcount(anys)
@row "n += isa(x, Int) in a trait module (hc7)" "interop" N tcount(anys)
@row "n += isnum(c) over DynamicItems{Cell}(v)" "view" N countnums(DynamicItems{Cell}(anys))
@row "n += isnum(c), countnums(v) with the user's Vector{Any}" "direct" N countnums(anys)
@row "n += isnum(c) over Vector{Dynamic{Cell}}" "copy" N countnums(w)
println("-- W3 count with a caller's predicate")
@row "n += f(x)::Bool, f a closure" "plain" N pcount_cb(pred_plain, anys)
@row "f::Callable{Tuple{Any}, Bool} (hc7)" "interop" N tcount_cb(pred_plain, anys)
@row "f::Callable{Tuple{Dynamic{Cell}}, Bool} over the view" "view" N countwhere(pred, DynamicItems{Cell}(anys))
@row "the same, compiled_call(f)" "view" N countwhere(compiled_call(pred), DynamicItems{Cell}(anys))
@row "the same, compiled_call(f), the user's vector" "direct" N countwhere(compiled_call(pred), anys)
@row "Callable{…, CompiledCall} over the copy" "copy" N countwhere_c(pred, w)
println("-- W4 a Dict{String,Any}'s pairs")
@row "for (k, v) in d; n += v isa Int" "plain" N pdictloop(dd)
@row "the same in a trait module (hc7)" "interop" N tdictloop(dd)
@row "for (k, c) in DynamicValues{Cell}(d); n += isnum(c)" "view" N countvals(DynamicValues{Cell}(dd))
@row "the same, countvals(d) with the user's Dict{String,Any}" "direct" N countvals(dd)
@row "the same over a Dict{String, Dynamic{Cell}}" "copy" N countvals(wd)
println("-- W5 keyed lookup, 1000 keys")
@row "s += d[k] (isa Int, else length)" "plain" N plookup(dd, ks)
@row "the same in a trait module" "interop" N tlookup(dd, ks)
@row "s += weight(d[k]) over DynamicValues{Cell}(d)" "view" N sumlookup(DynamicValues{Cell}(dd), ks)
@row "the same, the user's Dict{String,Any}" "direct" N sumlookup(dd, ks)
@row "the same over a Dict{String, Dynamic{Cell}}" "copy" N sumlookup(wd, ks)
println("-- W6 sums over numbers of mixed types (hc4's controls)")
@row "s += x over Vector{Any} of Int" "plain" N psumany(anyints)
@row "the same in a trait module" "interop" N tsumany(anyints)
@row "s += value(x) over DynamicItems{Num}(Vector{Any})" "view" N total(DynamicItems{Num}(anyints))
@row "the same, total(v) with the user's Vector{Any}" "direct" N total(anyints)
@row "s += Float64(x) over Vector{Real}" "plain" N psumreal(reals)
@row "the same in a trait module" "interop" N tsumreal(reals)
@row "s += value(x) over DynamicItems{Num}(Vector{Real})" "view" N total(DynamicItems{Num}(reals))
@row "the same, total(v) with the user's Vector{Real}" "direct" N total(reals)
@row "the same over a copy, Vector{Dynamic{Num}}" "copy" N total(wn)
println("-- the copy itself")
@row "collect(DynamicItems{Cell}(v)): Vector{Dynamic{Cell}}" "copy" N collect(DynamicItems{Cell}(anys))
@row "Dynamic{Cell}[Dynamic{Cell}(x) for x in v], in Main" "copy" N Dynamic{Cell}[Dynamic{Cell}(x) for x in anys]
@row "Dynamic{Cell}(x), x::Int known" "make" 1 Dynamic{Cell}($h600)
println("== done  load ", join(loadavg(), " "))
