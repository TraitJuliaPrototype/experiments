# Gate (W-100; compiler §2.3–§2.5): a method that takes the policy of the code reaching it (a
# boundary) runs code of the caller's policy, whichever way it is called: a generic call, a splat,
# `Core.invokelatest`, `Core.invoke`; the runtime's own entries reach with the setting's default.
# Under the test bed a session starts, user code's methods run facts code and the compiler stays
# plain.
include("util.jl")
const FACTS = 0x20

# one boundary function per way of calling, with two methods, so that a call at `Any` stays dynamic
for i in 1:5
    b = Symbol(:bound, i)
    @eval $b(x::Integer) = $(Expr(:block, Expr(:meta, :facts_boundary), :(x + one(x))))
    @eval $b(x::AbstractFloat) = $(Expr(:block, Expr(:meta, :facts_boundary), :(x * 2)))
end
plain_call(v::Vector{Any}) = bound1(v[1])
plain_splat(v::Vector{Any}) = bound2(v...)
plain_latest(v::Vector{Any}) = Core.invokelatest(bound3, v[1])
plain_invoke(v::Vector{Any}) = Core.invoke(bound4, Tuple{Integer}, v[1])

module FM
Base.Experimental.@compiler_options facts=true
import ..bound1, ..bound2, ..bound3, ..bound4
facts_call(v::Vector{Any}) = bound1(v[1])
facts_splat(v::Vector{Any}) = bound2(v...)
facts_latest(v::Vector{Any}) = Core.invokelatest(bound3, v[1])
facts_invoke(v::Vector{Any}) = Core.invoke(bound4, Tuple{Integer}, v[1])
end

# the policies of the native CodeInstances of every specialization of `f`'s method for integers
function policies(f)
    m = which(f, (Integer,))
    out = Symbol[]
    for mi in Base.specializations(m)
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            ci.owner === nothing && push!(out, (ci.flags & FACTS) != 0 ? :facts : :plain)
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
    return sort!(unique!(out))
end

@assert ccall(:jl_method_policy, Cint, (Any,), which(bound1, (Integer,))) == 2   # the caller's policy
for (b, p, f) in ((bound1, plain_call, FM.facts_call), (bound2, plain_splat, FM.facts_splat),
                  (bound3, plain_latest, FM.facts_latest), (bound4, plain_invoke, FM.facts_invoke))
    @assert p(Any[1]) == 2
    @assert policies(b) == [:plain] "plain $(nameof(p)): $(policies(b))"
    @assert f(Any[2]) == 3
    @assert policies(b) == [:facts, :plain] "facts $(nameof(f)): $(policies(b))"
end
# the runtime's own entry (C's jl_call) reaches with the setting's default: plain here
@assert ccall(:jl_call1, Any, (Any, Any), bound5, 1) == 2
@assert policies(bound5) == [:plain]

# the test bed: a session starts; user code's method runs facts code, the compiler's own plain
script = """
f(v) = sum(v) + length(v)
@assert f([1, 2, 3]) == 9
pol(mi) = (out = Symbol[]; ci = mi.cache; while true; ci.owner === nothing && push!(out, (ci.flags & 0x20) != 0 ? :facts : :plain); isdefined(ci, :next) || break; ci = ci.next; end; sort!(unique!(out)))
@assert pol(Base.method_instance(f, (Vector{Int},))) == [:facts]
@assert ccall(:jl_method_policy, Cint, (Any,), which(Base.Compiler.typeinf, (Base.Compiler.NativeInterpreter, Base.Compiler.InferenceState))) == 0
print("ok")
"""
out = withenv("JULIA_COMPILE_BY_FACTS" => "1") do
    read(`$(Base.julia_cmd()) --startup-file=no -e $script`, String)
end
@assert out == "ok" out
println("f6_reach_policy: OK")
