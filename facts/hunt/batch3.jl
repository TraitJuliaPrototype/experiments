include(joinpath(@__DIR__, "h.jl"))

# ---- C23 closures, Fix1, functions as values reaching abstract sites
module C23; g(x) = 1; end
k23(v) = (map(Base.Fix1(+, 1), v), map(x -> C23.g(x), v), sum(C23.g, v), foldl((a, b) -> a + C23.g(b), v; init = 0))
@wrap w23 k23
av = Any[1, 2.0]
check("C23 closures before", res(()->k23(av)), P(k23, av), res(()->w23(av)))
@eval C23 g(x::Float64) = 10
check("C23 closures after", res(()->k23(av)), P(k23, av), res(()->w23(av)))

# ---- C24 invokelatest / eval inside policy code
module C24; g(x) = 1; end
k24(x) = Base.invokelatest(C24.g, x)
@wrap w24 k24
check("C24 invokelatest before", res(()->k24(1)), P(k24, 1), res(()->w24(1)))
@eval C24 g(x) = 2
check("C24 invokelatest after", res(()->k24(1)), P(k24, 1), res(()->w24(1)))
k24b(n) = (Core.eval(C24, :(newf() = $n)); Base.invokelatest(C24.newf))
@wrap w24b k24b
check("C24b eval inside", res(()->k24b(5)), P(k24b, 6), res(()->w24b(7)))   # each returns its own n
# (above: compare on the n given; make the outcome n-independent)
k24c(n) = (Core.eval(C24, :(newg() = $n)); Base.invokelatest(C24.newg) == n)
@wrap w24c k24c
check("C24c eval inside (bool)", res(()->k24c(5)), P(k24c, 6), res(()->w24c(7)))

# ---- C25 const rebinding (binding partitions), typed globals, untyped globals
module C25; const K = 1; T::Int = 1; U = 1; end
k25() = (C25.K, C25.T, C25.U)
@wrap w25 k25
check("C25 globals before", res(k25), P(k25), res(w25))
@eval C25 const K = 2
@eval C25 T = 2
@eval C25 U = 2.0
check("C25 globals after", res(k25), P(k25), res(w25))
@eval C25 const K = "three"
check("C25 const rebound to another type", res(k25), P(k25), res(w25))
module C25b; f() = 1; end
k25b() = C25b.f()
@wrap w25b k25b
check("C25b binding replaced by const before", res(k25b), P(k25b), res(w25b))
@eval C25b const f = () -> 2
check("C25b binding replaced by const after", res(k25b), P(k25b), res(w25b))

# ---- C26 @nospecialize callees with abstract inner sites
module C26; g(x) = 1; h(@nospecialize(x)) = g(x); end
k26(x) = C26.h(x)
@wrap w26 k26
check("C26 nospecialize callee before", res(()->k26(1)), P(k26, 1), res(()->w26(1)))
@eval C26 g(x::Int) = 2
check("C26 nospecialize callee after", res(()->k26(1)), P(k26, 1), res(()->w26(1)))

# ---- C27 splatting
module C27; g(a, b) = 1; end
k27(t, v) = (C27.g(t...), C27.g(v...))
@wrap w27 k27
tt = (1, 2); vi = [1, 2]
check("C27 splat before", res(()->k27(tt, vi)), P(k27, tt, vi), res(()->w27(tt, vi)))
@eval C27 g(a::Int, b::Int) = 2
check("C27 splat after", res(()->k27(tt, vi)), P(k27, tt, vi), res(()->w27(tt, vi)))

# ---- C28 opaque closure
module C28; g(x) = 1; end
k28(x) = (oc = Base.Experimental.@opaque y -> C28.g(y); oc(x))
@wrap w28 k28
check("C28 opaque closure before", res(()->k28(1)), P(k28, 1), res(()->w28(1)))
@eval C28 g(x) = 2
check("C28 opaque closure after", res(()->k28(1)), P(k28, 1), res(()->w28(1)))

# ---- C29 MethodError and ambiguity created by a later method
module C29; g(x::Integer, y::Integer) = 1; end
k29(x, y) = C29.g(x, y)
@wrap w29 k29
k29a(v) = C29.g(v[1], v[2])
@wrap w29a k29a
aa = Any[1, 1]
check("C29 MethodError", res(()->k29(1.0, 1)), P(k29, 1.0, 1), res(()->w29(1.0, 1)))
check("C29 before ambiguity", res(()->k29(1, 1)), P(k29, 1, 1), res(()->w29(1, 1)), res(()->w29a(aa)), P(k29a, aa))
@eval C29 g(x::Int, y::Real) = 2
check("C29 after ambiguity", res(()->k29(1, 1)), P(k29, 1, 1), res(()->w29(1, 1)), res(()->w29a(aa)), P(k29a, aa))
@eval C29 g(x::Int, y::Integer) = 3
check("C29 ambiguity resolved", res(()->k29(1, 1)), P(k29, 1, 1), res(()->w29(1, 1)), res(()->w29a(aa)), P(k29a, aa))
# MethodError message text
k29m(x) = C29.g(x)
check("C29 MethodError text", res(()->k29m(1)), P(k29m, 1))
plaintext = try k29m(1) catch e; sprint(showerror, e) end
poltext = try TraitWorld._facts_call(k29m, 1) catch e; sprint(showerror, e) end
check("C29 MethodError full text", plaintext, poltext)

# ---- C30 delete_method
module C30; g(x::Integer) = 1; g(x::Int) = 2; end
k30(x) = C30.g(x)
@wrap w30 k30
k30a(v) = C30.g(v[1])
@wrap w30a k30a
check("C30 before delete", res(()->k30(1)), P(k30, 1), res(()->w30(1)), res(()->w30a(Any[1])))
Base.delete_method(only(methods(C30.g, Tuple{Int})))
check("C30 after delete specific", res(()->k30(1)), P(k30, 1), res(()->w30(1)), res(()->w30a(Any[1])))
Base.delete_method(only(methods(C30.g, Tuple{Integer})))
check("C30 after delete all", res(()->k30(1)), P(k30, 1), res(()->w30(1)), res(()->w30a(Any[1])))

# ---- C31 broadcast over empty arrays with compilation-signature widening (return_type fold)
module C31; passf(f) = f; ns(@nospecialize x) = x; pass(t) = t; end
k31() = (typeof(C31.passf.(typeof(sin)[])), typeof(C31.ns.(Int[])), typeof(C31.pass.(Type{Int}[])))
@wrap w31 k31
check("C31 empty broadcast eltypes", res(k31), P(k31), res(w31))
k31b(v) = typeof(C31.ns.(v))
@wrap w31b k31b
check("C31b empty broadcast eltype (arg)", res(()->k31b(Int[])), P(k31b, Int[]), res(()->w31b(Int[])))

# ---- C32 _facts_call with many arguments / Type arguments (entry signature widening)
module C32; h(xs...) = 1; h(a::Int, b::Int, c::Int, d::Int, e::Int, f::Int, g::Int, i::Int, j::Int, k::Int) = 2
            t(x) = 1; t(::Type{Int}) = 2; ff(f) = 1; ff(::typeof(sin)) = 2; end
check("C32 entry with 10 args", res(()->C32.h(1,2,3,4,5,6,7,8,9,10)), P(C32.h, 1,2,3,4,5,6,7,8,9,10))
check("C32 entry with Type arg", res(()->C32.t(Int)), P(C32.t, Int))
check("C32 entry with Function arg", res(()->C32.ff(sin)), P(C32.ff, sin))
@wrap w32 C32.h
check("C32 wrapped 10 args", res(()->C32.h(1,2,3,4,5,6,7,8,9,10)), res(()->w32(1,2,3,4,5,6,7,8,9,10)))

summary()
