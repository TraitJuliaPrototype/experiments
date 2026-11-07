# Gate (W-100, slice 2b; compiler §2.3, §2.4): a method of a module compiled by facts runs code
# compiled by facts, and its CodeInstance records the policy; plain code's does not; calls between
# the policies give the same results as plain Julia.
include("util.jl")
const CC = Core.Compiler
module FM
Base.Experimental.@compiler_options facts=true
g(x::Int) = x + 1
g(x::Float64) = x * 2.0
f(v::Vector{Any}) = g(v[1])              # g at Any: a run-time site under facts
h(x::Int) = g(x) + Main.plainhelp(x)     # a fact, and a call of plain code
end
plainhelp(x::Int) = 10x + FM.g(x)        # plain code calling facts code
pf(v::Vector{Any}) = FM.g(v[1])          # the same call, plain

@assert FM.f(Any[1]) == 2 && FM.f(Any[2.0]) == 4.0
@assert pf(Any[1]) == 2
@assert FM.h(3) == 4 + 30 + 4

function native_ci(f, T)
    mi = Base.method_instance(f, T)
    ci = isdefined(mi, :cache) ? mi.cache : nothing
    while ci !== nothing
        ci.owner === nothing && return ci
        ci = isdefined(ci, :next) ? ci.next : nothing
    end
    return nothing
end
cf = native_ci(FM.f, (Vector{Any},))
cp = native_ci(pf, (Vector{Any},))
@assert cf !== nothing && cp !== nothing
@assert (cf.flags & 0x20) != 0 && (cp.flags & 0x20) == 0
@assert !CC.is_nortsite(CC.decode_effects(cf.ipo_purity_bits))     # facts code with a run-time site
@assert CC.is_nortsite(CC.decode_effects(cp.ipo_purity_bits))      # plain code has none
println("f3_policy_code: OK")
