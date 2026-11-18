# E-145, third run: the table by type made cheap, against the carried witness; and the cost of a
# pointer the first time a type is met. Same 64 types as e145b (area only), plus 8 types met late.
#   s4+hash   e145b's table (keys, then a vector of witness objects, then the pointer: 3 loads)
#   s4+tab    a table per call signature: (type address, pointer) pairs side by side, one probe
#   s4+wit    the carried witness (e145b)
#   tab       the table alone, no split
#     ./run.sh product --project=. e145c.jl         (E145_N=131072 for the large mix)
include("common.jl")
using TraitWorld, Random, Printf, InteractiveUtils
src = read(joinpath(@__DIR__, "e145b.jl"), String)
include_string(Main, split(split(src, "header(\"e145b\")")[2], "rng = Xoshiro(145)")[1], joinpath(@__DIR__, "e145b.jl"))
println("== e145c  elements per mix ", N, "  load ", join(loadavg(), " "))

"A table per call signature: slot i holds the type's address and the pointer, side by side."
mutable struct SigTable
    kv::Vector{UInt}          # 2i-1: the type's address (types are rooted by TYPES), 2i: the pointer
    mask::Int
end
@inline function probe(t::SigTable, @nospecialize(T))
    a = reinterpret(UInt, pointer_from_objref(T))
    i = (a >> 4) % Int & t.mask
    kv = t.kv
    while true
        k = @inbounds kv[2i + 1]
        k === a && return reinterpret(Ptr{Cvoid}, @inbounds kv[2i + 2])
        k === UInt(0) && return C_NULL
        i = (i + 1) & t.mask
    end
end
const AREA_TAB = SigTable(zeros(UInt, 512), 255)
for T in TYPES
    a = reinterpret(UInt, pointer_from_objref(T)); i = (a >> 4) % Int & 255
    while AREA_TAB.kv[2i + 1] != 0; i = (i + 1) & 255; end
    AREA_TAB.kv[2i + 1] = a; AREA_TAB.kv[2i + 2] = reinterpret(UInt, Base.invokelatest(cw_ptr, typeof(area), T))
end
struct FbTab end
@inline (::FbTab)(x) = ccall(probe(AREA_TAB, typeof(x)), Float64, (Any,), x)
s_tab(v::Vector{Dyn}, sp::P) where {P} = (s = 0.0; for d in v; s += sp(d.t, FbTab()); end; s)
s_tabonly(v::Vector{Dyn}) = (s = 0.0; for d in v; s += FbTab()(d.t); end; s)

rng = Xoshiro(145)
mixes = Any[("uniform n=$n", Any[mk(TYPES[rand(rng, 1:n)], 1.0) for _ in 1:N]) for n in (8, 16, 64)]
push!(mixes, ("skewed n=64", Any[rand(rng) < 0.9 ? mk(T5, 1.0) : mk(TYPES[rand(rng, 1:64)], 1.0) for _ in 1:N]))
push!(mixes, ("cyclic n=64", Any[mk(TYPES[mod1(i, 64)], 1.0) for i in 1:N]))
const S4 = make_split(area, TYPES[1:4])
for (name, va) in mixes
    vd = Dyn[Dyn(x) for x in va]; vw = DynW[mkw(x) for x in va]
    @assert s_hash(vd, S4, Val(:area)) ≈ s_tab(vd, S4) ≈ s_wit(vw, S4, Val(:area)) ≈ s_tabonly(vd)
    println("-- ", name)
    @row "area s4+hash: split 4 + e145b's table" name N s_hash($vd, $S4, Val(:area))
    @row "area s4+tab: split 4 + table per signature, one probe" name N s_tab($vd, $S4)
    @row "area s4+wit: split 4 + carried witness" name N s_wit($vw, $S4, Val(:area))
    @row "area tab: table per signature only" name N s_tabonly($vd)
    @row "area wit: carried witness only" name N s_witonly($vw, Val(:area))
end
# the first time a type is met: its pointer (the callable compiled at the type, and the thunk)
println("-- a pointer for a type met late: time to make it")
let io = IOBuffer()
    for i in 65:72
        println(io, "struct T$i; a::Float64; end; area(x::T$i) = $(1.0 + i / 64) * x.a")
    end
    include_string(Main, String(take!(io)), joinpath(@__DIR__, "e145c_late.jl"))
end
for i in 65:72
    T = getglobal(Main, Symbol(:T, i))
    t = @elapsed (fp = Base.invokelatest(cw_ptr, typeof(area), T))
    t2 = @elapsed ccall(fp, Float64, (Any,), T(2.0))
    @printf("%-8s %-12s T%d: pointer made in %6.2f ms, first call through it %6.3f ms\n", SETTING, "first", i, 1000t, 1000t2)
end
println("== done  load ", join(loadavg(), " "))
