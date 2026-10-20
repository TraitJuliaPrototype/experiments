# E2: a Vector of a Union of k concrete types, k = 2..6, summing a method per type; plain against all.
# Beyond four splits the facts mode makes the call a run-time site; plain Julia also stops splitting
# the union at 4 but then speculates over the methods (max_methods = 3) or falls back to dispatch.
using BenchmarkTools
mode = Base.Compiler.NativeInterpreter().facts ? "all  " : "plain"
struct A; v::Float64; end
struct B; v::Float64; end
struct C; v::Float64; end
struct D; v::Float64; end
struct E; v::Float64; end
struct F; v::Float64; end
ar(s::A) = s.v; ar(s::B) = 2s.v; ar(s::C) = 3s.v; ar(s::D) = 4s.v; ar(s::E) = 5s.v; ar(s::F) = 6s.v
const TS = (A, B, C, D, E, F)
const N = 1000
site(v) = (s = 0.0; for x in v; s += ar(x); end; s)           # the result untyped, as user code writes it
site_t(v) = (s = 0.0; for x in v; s += ar(x)::Float64; end; s) # the result asserted
for k in 2:6
    U = Union{TS[1:k]...}
    v = U[TS[mod1(i, k)](1.0) for i in 1:N]
    t = @belapsed site($v); tt = @belapsed site_t($v)
    a = (site(v); @allocated site(v))
    println(mode, "  Union of ", k, "  untyped ", lpad(round(1e9 * t / N; digits = 2), 6), " ns/elt  asserted ",
            lpad(round(1e9 * tt / N; digits = 2), 6), " ns/elt  ", lpad(round(a / N; digits = 1), 5), " B/elt")
end
# an abstract element type with k subtypes (plain: max_methods speculation up to 3 methods)
abstract type Sh end
struct P1 <: Sh; v::Float64; end
struct P2 <: Sh; v::Float64; end
struct P3 <: Sh; v::Float64; end
struct P4 <: Sh; v::Float64; end
pa(s::P1) = s.v; pa(s::P2) = 2s.v
psite(v) = (s = 0.0; for x in v; s += pa(x); end; s)
for k in (2, 3, 4)
    k >= 3 && !hasmethod(pa, Tuple{P3}) && @eval pa(s::P3) = 3s.v
    k >= 4 && !hasmethod(pa, Tuple{P4}) && @eval pa(s::P4) = 4s.v
    PS = (P1, P2, P3, P4)
    v = Sh[PS[mod1(i, k)](1.0) for i in 1:N]
    t = @belapsed psite($v)
    a = (psite(v); @allocated psite(v))
    println(mode, "  Vector{Sh}, ", k, " methods  ", lpad(round(1e9 * t / N; digits = 2), 6), " ns/elt  ", lpad(round(a / N; digits = 1), 5), " B/elt")
end
