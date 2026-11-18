# Does an owned (non-pirate) method whose only owned type sits in a Vararg tail
# invalidate facts code at a concrete fact where its definer is no stakeholder?
module Lib
g(x::Integer) = 1
end
module M
Base.Experimental.@compiler_options facts=true
k(x::Int) = Main.Lib.g(x)
end
function cis(mi)
    out = Any[]
    isdefined(mi, :cache) || return out
    ci = mi.cache
    while true
        push!(out, (ci.owner, ci.max_world == typemax(UInt) ? :inf : ci.max_world))
        isdefined(ci, :next) || break
        ci = ci.next
    end
    return out
end
println("k(1) before: ", M.k(1))
mi = first(Base.specializations(only(methods(M.k))))
println("CIs of M.k(::Int) before: ", cis(mi))
println("is_fact_sig(Tuple{typeof(g), Int}) = ", Base.Compiler.is_fact_sig(Tuple{typeof(Lib.g), Int}))
module P
struct MyT end
Main.Lib.g(x::Int, y::MyT...) = 2
end
println("CIs of M.k(::Int) after P's g(::Int, ::MyT...): ", cis(mi))
println("k(1) after: ", M.k(1))
println("morespecific(g(::Int, ::MyT...), g(::Integer)) = ",
        ccall(:jl_type_morespecific, Cint, (Any, Any), Tuple{typeof(Lib.g), Int, Vararg{P.MyT}}, Tuple{typeof(Lib.g), Integer}))
# zero-arity takeover of a Base function by an owned varargs method
println("vcat() before: ", repr(vcat()))
module Q
struct T2 end
Base.vcat(x::T2...) = :taken
end
println("vcat() after Q's vcat(::T2...): ", repr(vcat()))
println("done; VERSION = ", VERSION, " ", Base.GIT_VERSION_INFO.commit[1:10])
