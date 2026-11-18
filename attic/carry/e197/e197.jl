# E-197 (W-74 (1), T-51): one varargs method behind an erased function's pointer, in place of the fixed arities.
# A copy of TraitWorld's `Erased` (src/core.jl) whose wrapper is `(::W{S})(o, args::Vararg{Any,N})`, without
# the six-argument limit, against TraitWorld's own `Erased` (arities up to six) and a direct call.
#     julia --project=../../../TraitWorld e197.jl
using TraitWorld
const TW = TraitWorld

module V
import ..TW: _PtrCell, _ctype, _cdecl
struct Erased{A,S}
    cell::_PtrCell
    obj::Any
end
struct W{S} end
(::W{S})(o, args::Vararg{Any,N}) where {S,N} = o(args...)::S
@generated function _fptr(::Type{A}, ::Type{S}, ::Type{F}) where {A,S,F}
    ats = Any[_cdecl(a) for a in (A::DataType).parameters]
    return Expr(:cfunction, Ptr{Cvoid}, QuoteNode(W{S}()), _ctype(S),
                :(Core.svec($(Ref{F}), $(ats...))), QuoteNode(:caller_world))
end
Erased{A,S}(@nospecialize(f)) where {A,S} = Erased{A,S}(_PtrCell(C_NULL), f)
@noinline function _slow(e::Erased{A,S}) where {A,S}
    p = Base.invokelatest(_fptr, A, S, typeof(getfield(e, :obj)))::Ptr{Cvoid}
    @atomic getfield(e, :cell).ptr = p
    return p
end
@generated function (e::Erased{A,S})(args...) where {A,S}
    ats = Any[_ctype(a) for a in (A::DataType).parameters]
    argex = [:(args[$i]) for i in 1:length(ats)]
    return quote
        Base.@_inline_meta
        p = @atomic :monotonic getfield(e, :cell).ptr
        p == C_NULL && (p = _slow(e))
        x = ccall(p, $(_ctype(S)), (Any, $(ats...)), e.obj, $(argex...))
        x::$S
    end
end
end

struct Box; v::Vector{Float64}; end          # a non-bits argument
fb(xs::Float64...) = sum(xs)
fn(xs::Box...) = sum(x -> x.v[1], xs)

callee(x) = x isa Core.CodeInstance ? callee(x.def) : x isa Core.MethodInstance ? x.def.name : x

# one erased call site per (form, arity, element), called in a loop; the loop is compiled for the erased type only
@noinline function loop(e, args, n)
    s = 0.0
    for _ in 1:n
        s += e(args...)
    end
    return s
end
function measure(label, e, args; n = 10^6)
    loop(e, args, 1)                                     # compile, and make the pointer
    t = minimum(@elapsed(loop(e, args, n)) for _ in 1:5)
    a = @allocated loop(e, args, n)
    println(rpad(label, 34), lpad(round(t / n * 1e9; digits = 2), 8), " ns/call  ", lpad(a, 8), " bytes / ", n, " calls")
end

println("V julia ", Base.GIT_VERSION_INFO.commit_short, " TraitWorld ", readchomp(`git -C $(pkgdir(TW)) rev-parse --short HEAD`))
for (elt, f, mk) in ((Float64, fb, i -> Float64(i)), (Box, fn, i -> Box([Float64(i)])))
    for k in (1, 3, 6, 8, 12)
        A = Tuple{ntuple(_ -> elt, k)...}
        args = ntuple(mk, k)
        measure("direct  $(nameof(elt)) x$k", f, args)
        measure("varargs $(nameof(elt)) x$k", V.Erased{A,Float64}(f), args)
        k <= 6 && measure("fixed   $(nameof(elt)) x$k", TW.Erased{A,Float64}(f), args)
        # the code behind the pointer: the wrapper at the cfunction's signature
        sig = Tuple{V.W{Float64}, typeof(f), (elt === Float64 ? ntuple(_ -> Float64, k) : ntuple(_ -> Box, k))...}
        ci, rt = only(Base.code_typed_by_type(sig; optimize = true))
        calls = [st for st in ci.code if st isa Expr && st.head in (:call, :invoke, :foreigncall)]
        println("C wrapper $(nameof(elt)) x$k: returns ", rt, "; ", length(ci.code), " statements; calls: ",
                join(unique(string(st.head, ":", st.head === :invoke ? callee(st.args[1]) : st.args[1]) for st in calls), ", "))
    end
end
