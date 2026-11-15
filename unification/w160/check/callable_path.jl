# W-160 (d), E-442: what a call through `Dynamic{Callable{Tuple{Float64}, Float64}}` costs, part by part
# (E-437's row 6: 152 ns a call on `next`). Each row: a loop of 10^7 calls, the minimum of 5, ns a call.
using TraitWorld
f(x::Float64) = x * 1.0000001
const C = Callable{Tuple{Float64}, Float64}
const DF = Dynamic{C}(f)
const N = 10^7
const SINK = Ref(0.0)
ns(h, args...) = (h(args..., 10); round(minimum(@elapsed(SINK[] += h(args..., N)) for _ in 1:5) / N * 1e9; digits = 2))
# 1. the box's call as the library defines it
l1(d, x, n) = (for _ in 1:n; x = d(x); end; x)
# 2. the object read at its declared type (`Callable{A, S}`, abstract) and called with one argument: a dynamic call
callobj(d::Dynamic{C}, x::Float64) = getfield(d, :object)(x)
l2(d, x, n) = (for _ in 1:n; x = callobj(d, x)::Float64; end; x)
# 3. the same, the arguments splatted as the box's call does (`args...`)
callsplat(d::Dynamic{C}, args...) = getfield(d, :object)(args...)
l3(d, x, n) = (for _ in 1:n; x = callsplat(d, x)::Float64; end; x)
# 4. a dynamic call of a function held as `Any`, Julia's own barrier: the floor of any erased call
const ANYF = Ref{Any}(f)
l4(x, n) = (for _ in 1:n; x = ANYF[](x)::Float64; end; x)
# 5. the object's type test against `Callable{A, S}` when it runs (a membership by methods, C-116)
l5(x, n) = (s = 0; for _ in 1:n; s += ANYF[] isa C; end; Float64(s))
println("1 the box's call                          ", ns(l1, DF, 1.0))
println("2 the object called, one argument         ", ns(l2, DF, 1.0))
println("3 the object called, arguments splatted   ", ns(l3, DF, 1.0))
println("4 a function held as Any, called          ", ns(l4, 1.0))
println("5 isa Callable{A, S} when it runs         ", ns(l5, 1.0))
