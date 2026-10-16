include(joinpath(@__DIR__, "h.jl"))

# ---- C1 hasmethod at a concrete signature, method added later
module H1; g(x::Integer) = 1; end
k1() = hasmethod(H1.g, Tuple{Float64})
@wrap w1 k1
check("C1 hasmethod concrete before", res(k1), P(k1), res(w1))
@eval H1 g(x::Float64) = 2
check("C1 hasmethod concrete after add", res(k1), P(k1), res(w1))
Base.delete_method(only(methods(H1.g, Tuple{Float64})))
check("C1 hasmethod concrete after delete", res(k1), P(k1), res(w1))

# ---- C2 hasmethod at an abstract signature
module H2; g(x::Int) = 1; end
k2() = hasmethod(H2.g, Tuple{Real})
@wrap w2 k2
check("C2 hasmethod abstract before", res(k2), P(k2), res(w2))
@eval H2 g(x::Real) = 2
check("C2 hasmethod abstract after add", res(k2), P(k2), res(w2))

# ---- C2b hasmethod with a type known only at run time (abstract argument)
module H2b; g(x::Int) = 1; end
k2b(T) = hasmethod(H2b.g, Tuple{T})
@wrap w2b k2b
check("C2b hasmethod(T) before", res(()->k2b(Float32)), P(k2b, Float32), res(()->w2b(Float32)))
@eval H2b g(x::Float32) = 2
check("C2b hasmethod(T) after", res(()->k2b(Float32)), P(k2b, Float32), res(()->w2b(Float32)))

# ---- C3 applicable at concrete types
module A3; g(x::Int) = 1; end
k3(x) = applicable(A3.g, x)
@wrap w3 k3
check("C3 applicable concrete before", res(()->k3(1.0)), P(k3, 1.0), res(()->w3(1.0)))
@eval A3 g(x::Float64) = 2
check("C3 applicable concrete after", res(()->k3(1.0)), P(k3, 1.0), res(()->w3(1.0)))

# ---- C4 applicable at abstract types
module A4; g(x::Int) = 1; end
k4(v) = applicable(A4.g, v[1])
@wrap w4 k4
vv = Any[1.0]
check("C4 applicable abstract before", res(()->k4(vv)), P(k4, vv), res(()->w4(vv)))
@eval A4 g(x::Float64) = 2
check("C4 applicable abstract after", res(()->k4(vv)), P(k4, vv), res(()->w4(vv)))

# ---- C5 which / methods
module W5; g(x::Integer) = 1; end
k5() = (length(methods(W5.g)), which(W5.g, Tuple{Int}).sig)
@wrap w5 k5
check("C5 which/methods before", res(k5), P(k5), res(w5))
@eval W5 g(x::Int) = 2
check("C5 which/methods after", res(k5), P(k5), res(w5))

# ---- C6 invoke with a later more specific method and redefinition of the invoked one
module I6; g(x::Integer) = 1; end
k6(x) = invoke(I6.g, Tuple{Integer}, x)
@wrap w6 k6
check("C6 invoke before", res(()->k6(1)), P(k6, 1), res(()->w6(1)))
@eval I6 g(x::Int) = 2
check("C6 invoke after more specific", res(()->k6(1)), P(k6, 1), res(()->w6(1)))
@eval I6 g(x::Integer) = 3
check("C6 invoke after redefinition", res(()->k6(1)), P(k6, 1), res(()->w6(1)))

# ---- C7 invoke at Any whose body has an abstract site
module I7; h(x) = 1; g(x) = h(Base.inferencebarrier(x)); end
k7(x) = invoke(I7.g, Tuple{Any}, x)
@wrap w7 k7
check("C7 invoke(Any) before", res(()->k7(1)), P(k7, 1), res(()->w7(1)))
@eval I7 h(x) = 2
check("C7 invoke(Any) after callee redefinition", res(()->k7(1)), P(k7, 1), res(()->w7(1)))
@eval I7 h(x::Int) = 3
check("C7 invoke(Any) after callee specific", res(()->k7(1)), P(k7, 1), res(()->w7(1)))

# ---- C8 generated function
module G8; g(x) = 1; @generated gen(x) = :(g(x) + 10); end
k8(x) = G8.gen(x)
@wrap w8 k8
check("C8 generated before", res(()->k8(1)), P(k8, 1), res(()->w8(1)))
@eval G8 g(x::Int) = 2
check("C8 generated after callee method", res(()->k8(1)), P(k8, 1), res(()->w8(1)))

# ---- C8b generated function whose generator calls hasmethod
module G8b; g(x::Int) = 1; @generated gen(x) = hasmethod(g, Tuple{x}) ? :(1) : :(2); end
k8b(x) = G8b.gen(x)
@wrap w8b k8b
check("C8b generator hasmethod before", res(()->k8b(1.0)), P(k8b, 1.0), res(()->w8b(1.0)))
@eval G8b g(x::Float64) = 1
check("C8b generator hasmethod after", res(()->k8b(1.0)), P(k8b, 1.0), res(()->w8b(1.0)))

# ---- C9 keyword functions
module K9; f(x; k = 1) = x + k; end
k9(x) = K9.f(x; k = 2)
@wrap w9 k9
check("C9 kwcall before", res(()->k9(1)), P(k9, 1), res(()->w9(1)))
@eval K9 f(x::Int; k = 1) = 100k
check("C9 kwcall after more specific", res(()->k9(1)), P(k9, 1), res(()->w9(1)))
k9b(x, v) = K9.f(x; k = v[1])        # abstract keyword value
@wrap w9b k9b
check("C9b kwcall abstract kw before", res(()->k9b(1, Any[3])), P(k9b, 1, Any[3]), res(()->w9b(1, Any[3])))
@eval K9 f(x::Int; k = 1) = 1000k
check("C9b kwcall abstract kw after", res(()->k9b(1, Any[3])), P(k9b, 1, Any[3]), res(()->w9b(1, Any[3])))

# ---- C10 varargs
module V10; va(xs...) = length(xs); end
k10(a, b) = V10.va(a, b)
@wrap w10 k10
check("C10 varargs before", res(()->k10(1, 2)), P(k10, 1, 2), res(()->w10(1, 2)))
@eval V10 va(x::Int, y::Int) = -1
check("C10 varargs after", res(()->k10(1, 2)), P(k10, 1, 2), res(()->w10(1, 2)))

# ---- C11 Type{T} arguments
module T11; ty(::Type{T}) where {T} = 1; end
k11() = T11.ty(Int)
@wrap w11 k11
check("C11 Type{T} before", res(k11), P(k11), res(w11))
@eval T11 ty(::Type{Int}) = 2
check("C11 Type{T} after", res(k11), P(k11), res(w11))
k11b(T) = T11.ty(T)
@wrap w11b k11b
check("C11b Type value arg", res(()->k11b(Int)), P(k11b, Int), res(()->w11b(Int)))
@eval T11 ty(::Type{Int}) = 3
check("C11b Type value arg after", res(()->k11b(Int)), P(k11b, Int), res(()->w11b(Int)))

# ---- C12 union splitting
module U12; g(x::Real) = 1; end
k12(v) = U12.g(v[1])
@wrap w12 k12
uv = Union{Int,Float64}[1.0]
check("C12 union split before", res(()->k12(uv)), P(k12, uv), res(()->w12(uv)))
@eval U12 g(x::Float64) = 2
check("C12 union split after", res(()->k12(uv)), P(k12, uv), res(()->w12(uv)))

summary()
