# E6: how many splits Julia's union splitting admits, plain and under the facts image: one Union
# argument of 6 and 8 members, and two Union arguments (2 x 3 = 6 signatures). Counts the generic
# (dynamic) calls left in the compiled code, and times the loop.
using BenchmarkTools
mode = Base.Compiler.NativeInterpreter().facts ? "all  " : "plain"
struct A; v::Float64; end
struct B; v::Float64; end
struct C; v::Float64; end
struct D; v::Float64; end
struct E; v::Float64; end
struct F; v::Float64; end
struct G; v::Float64; end
struct H; v::Float64; end
ar(s::A) = s.v; ar(s::B) = 2s.v; ar(s::C) = 3s.v; ar(s::D) = 4s.v; ar(s::E) = 5s.v; ar(s::F) = 6s.v; ar(s::G) = 7s.v; ar(s::H) = 8s.v
const TS = (A, B, C, D, E, F, G, H)
const N = 1000
site(v) = (s = 0.0; for x in v; s += ar(x); end; s)
ngeneric(f, T) = (ct = code_typed(f, T)[1][1]; count(s -> s isa Expr && s.head === :call && occursin("ar", sprint(show, s)), ct.code))
ninvoke(f, T) = (ct = code_typed(f, T)[1][1]; count(s -> s isa Expr && s.head === :invoke, ct.code))
println("unionsplitcost of (ar, Union of 6): ", Base.Compiler.unionsplitcost(Base.Compiler.SimpleInferenceLattice.instance, Any[typeof(ar), Union{TS[1:6]...}]),
        ";  of (two, Union of 2, Union of 3): ", Base.Compiler.unionsplitcost(Base.Compiler.SimpleInferenceLattice.instance, Any[typeof(ar), Union{A,B}, Union{A,B,C}]),
        ";  of (two, Union of 3, Union of 3): ", Base.Compiler.unionsplitcost(Base.Compiler.SimpleInferenceLattice.instance, Any[typeof(ar), Union{A,B,C}, Union{A,B,C}]))
for k in (4, 5, 6, 8)
    U = Union{TS[1:k]...}
    v = U[TS[mod1(i, k)](1.0) for i in 1:N]
    t = @belapsed site($v)
    println(mode, "  one Union of ", k, ": generic `ar` calls in site ", ngeneric(site, Tuple{Vector{U}}), ", ",
            lpad(round(1e9 * t / N; digits = 2), 6), " ns/elt, ", @allocated(site(v)) / N, " B/elt")
end
two(x, y) = ar(x) + ar(y)
site2(v, w) = (s = 0.0; for i in eachindex(v); s += two(v[i], w[i]); end; s)
for (k1, k2) in ((2, 2), (2, 3), (3, 3), (4, 4))
    U1 = Union{TS[1:k1]...}; U2 = Union{TS[1:k2]...}
    v = U1[TS[mod1(i, k1)](1.0) for i in 1:N]; w = U2[TS[mod1(i, k2)](1.0) for i in 1:N]
    t = @belapsed site2($v, $w)
    println(mode, "  two Unions of ", k1, " x ", k2, ": generic calls in `two` ", ngeneric(two, Tuple{U1, U2}), ", ",
            lpad(round(1e9 * t / N; digits = 2), 6), " ns/elt, ", @allocated(site2(v, w)) / N, " B/elt")
end
