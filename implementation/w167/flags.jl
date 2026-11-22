# W-167: the runtime's flags of a CodeInstance, read through the runtime's own definitions, not a hard-coded mask
# (open issue 257). `include` it; it checks itself when included (a reader that does not discriminate stops the run).
#   facts(ci)  compiled by facts: the Compiler's own accessor `Base.Compiler.ci_policy_facts`
#   g2(ci)     deep G2 (compiler §3.2): the bit `JL_CI_FLAGS_G2` as the build's installed `julia.h` defines it (the
#              runtime has no reader of its own; the Compiler's `edges_satisfy_g2` decides it and `jl_ci_set_g2`
#              sets it)
#   fromimage(ci)  loaded from an image: `JL_CI_FLAGS_FROM_IMAGE`, the same way
# The self-check: a module compiled by facts with a deep leaf, a run-time site (deep) and a caller of a plain callee
# outside the class (not deep), as gates' `gate_deep.jl` (W-155) pins them; and plain code reads facts = false.
module W167Flags
const HDR = normpath(joinpath(Sys.BINDIR, "..", "include", "julia", "julia.h"))
function ci_flag(name::AbstractString)
    isfile(HDR) || error("W167Flags: no julia.h at $HDR")
    for l in eachline(HDR)
        m = match(Regex("^#define\\s+" * name * "\\s+(0b[01]+|0x[0-9a-fA-F]+|\\d+)"), l)
        m === nothing || return UInt8(parse(Int, m.captures[1]))
    end
    error("W167Flags: $name is not defined in $HDR")
end
const G2 = ci_flag("JL_CI_FLAGS_G2")
const FROM_IMAGE = ci_flag("JL_CI_FLAGS_FROM_IMAGE")
flags(ci::Core.CodeInstance) = getfield(ci, :flags, :monotonic)::UInt8
facts(ci::Core.CodeInstance) = Base.Compiler.ci_policy_facts(ci)
g2(ci::Core.CodeInstance) = (flags(ci) & G2) != 0
fromimage(ci::Core.CodeInstance) = (flags(ci) & FROM_IMAGE) != 0

# the native CodeInstances of a MethodInstance, valid now
function natives(mi::Core.MethodInstance)
    out = Core.CodeInstance[]
    isdefined(mi, :cache) || return out
    ci = mi.cache
    while true
        ci.owner === nothing && ci.max_world == typemax(UInt) && push!(out, ci)
        isdefined(ci, :next) || break
        ci = ci.next
    end
    out
end

module Probe
module P
leaf(x::Int) = x + 1
@noinline spec(v::Vector{Any}) = leaf(v[1])          # a call at Any, inferred plainly: outside the class
end
module F
Base.Experimental.@compiler_options facts = true
import ..P
deep(x::Int) = P.leaf(x) * 2                           # a call at a fact signature, its callee deep
rt(v::Vector{Any}) = P.leaf(v[1])                      # a run-time site: no edge, deep
up(x::Int) = P.spec(Any[x])                            # rests on a plain callee outside the class
end
end
function selfcheck()
    P, F = Probe.P, Probe.F
    @assert F.deep(1) == 4 && F.rt(Any[1]) == 2 && F.up(1) == 2 && P.leaf(1) == 2
    one(f, T) = (c = natives(Base.method_instance(f, T)); length(c) == 1 || error("W167Flags: $(f)$(T): $(length(c)) native instances"); c[1])
    checks = [
        (facts(one(F.deep, (Int,))), "facts code reads facts"),
        (!facts(one(P.leaf, (Int,))), "plain code reads plain"),
        (g2(one(F.deep, (Int,))), "a deep caller reads deep"),
        (g2(one(F.rt, (Vector{Any},))), "a run-time site reads deep"),
        (!g2(one(F.up, (Int,))), "a caller of a plain callee outside the class reads not deep"),
        (!g2(one(P.spec, (Vector{Any},))), "plain code with a call at Any reads not deep"),
    ]
    bad = [w for (c, w) in checks if !c]
    isempty(bad) || error("W167Flags self-check FAILED (G2 = $(repr(G2)) from $HDR): " * join(bad, "; "))
    return "flags: facts by Compiler.ci_policy_facts, G2 = $(repr(G2)) and FROM_IMAGE = $(repr(FROM_IMAGE)) from julia.h; self-check ok"
end
const CHECKED = selfcheck()
end
