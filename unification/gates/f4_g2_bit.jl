# Gate (W-100, slice 3; compiler §3.2): a CodeInstance of either policy records whether its record
# satisfies G2: every dispatch edge at a fact signature.
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
println("f4_g2_bit: OK")
