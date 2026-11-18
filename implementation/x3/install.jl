# E-269 (X3): methods at an open set on Base's getindex, iterate and length, with k members.
# On the unified build `OpenColl` is a set and its members join by memberships; on vanilla it is a
# plain abstract type and its members are its declared subtypes (the closed-world equivalent).
const unified = isdefined(Core, :MembershipEntry)
const K = parse(Int, get(ENV, "X3_MEMBERS", "0"))
function mkset(name::Symbol)
    T = Core._abstracttype(Main, name, Core.svec())
    unified && ccall(:jl_set_open_set, Cvoid, (Any,), T)
    Core._setsuper!(T, Any)
    Core._typebody!(false, T)
    Core.declare_const(Main, name, T)
    return getglobal(Main, name)
end
if K > 0
    S = mkset(:OpenColl)
    @eval begin
        Base.getindex(x::OpenColl, i::Int) = i
        Base.iterate(x::OpenColl, s::Int = 1) = s > 3 ? nothing : (s, s + 1)
        Base.length(x::OpenColl) = 3
    end
    for i in 1:K
        name = Symbol(:Member, i)
        if unified
            @eval struct $name end
            ccall(:jl_declare_membership, Any, (Any, Any, Any, Any, Any),
                  getglobal(Main, name), S, Main, nothing, :self)
        else
            @eval struct $name <: OpenColl end
        end
    end
end
