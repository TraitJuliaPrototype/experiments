# Gate (W-100, slice 3; compiler §3.2): a CodeInstance of either policy records whether its record
# satisfies G2: every dispatch edge at a fact signature; an inlined callee's record read on the edge's
# instance, a constant-propagated result's included (C-75).
include("util.jl")
a(x::Int) = x + 1
c(x::Int) = a(x)                  # every call at a fact signature
b(v::Vector{Any}) = a(v[1])       # a call at Any
@assert c(1) == 2 && b(Any[1]) == 2
function native_ci(f, T)
    mi = Base.method_instance(f, T)
    ci = isdefined(mi, :cache) ? mi.cache : nothing
    while ci !== nothing
        ci.owner === nothing && return ci
        ci = isdefined(ci, :next) ? ci.next : nothing
    end
    return nothing
end
@assert (native_ci(c, (Int,)).flags & 0x10) != 0
@assert (native_ci(b, (Vector{Any},)).flags & 0x10) == 0
module FM
Base.Experimental.@compiler_options facts=true
a(x::Int) = x + 1
b(v::Vector{Any}) = a(v[1])       # a run-time site under facts: no edge, so G2 holds
end
@assert FM.b(Any[1]) == 2
@assert (native_ci(FM.b, (Vector{Any},)).flags & 0x30) == 0x30      # facts, and G2
# (C-75) a caller that inlines Base's `push!` keeps G2: `push!`'s record names the edge instance a
# constant-propagated callee's result makes (`_growend!`), which carries the bit as a cached result does
module FP
Base.Experimental.@compiler_options facts=true
addone(v::Vector{String}) = push!(v, "a")
end
@assert FP.addone(String[]) == ["a"]
@assert (native_ci(FP.addone, (Vector{String},)).flags & 0x30) == 0x30 "facts, and G2 through push!: $(native_ci(FP.addone, (Vector{String},)).flags)"
println("f4_g2_bit: OK")
