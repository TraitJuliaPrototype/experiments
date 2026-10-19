# Inline caches, stage 0: what a dynamic call site costs, plain and under `all` (the facts image),
# for a monomorphic and a polymorphic site, a site in Base (`push!` on `Vector{Any}`), and a site
# whose result feeds arithmetic.   julia [-J facts/sys.so] --project=<env with BenchmarkTools> sites.jl
using BenchmarkTools
abstract type Sh end
struct A <: Sh; v::Float64; end
struct B <: Sh; v::Float64; end
struct C <: Sh; v::Float64; end
struct D <: Sh; v::Float64; end
ar(s::A) = s.v; ar(s::B) = 2s.v; ar(s::C) = 3s.v; ar(s::D) = 4s.v
const N = 1000
const MONO = Any[A(1.0) for _ in 1:N]
const POLY = Any[(A, B, C, D)[mod1(i, 4)](1.0) for i in 1:N]
const INTS = Any[i for i in 1:N]
site(v) = (s = 0.0; for x in v; s += ar(x)::Float64; end; s)            # result asserted
site_any(v) = (s = 0.0; for x in v; s += ar(x); end; s)                   # result used untyped
pushall(v) = (out = Any[]; for x in v; push!(out, x); end; out)
mode = Base.Compiler.NativeInterpreter().facts ? "all  " : "plain"
for (name, f, v) in (("monomorphic, asserted", site, MONO), ("4 types, asserted", site, POLY),
                     ("4 types, result untyped", site_any, POLY), ("push!(::Vector{Any}, x)", pushall, INTS))
    f(v)
    t = @belapsed $f($v)
    a = (f(v); @allocated f(v))
    println(mode, "  ", rpad(name, 26), lpad(round(1e9 * t / N; digits = 1), 7), " ns/call  ", lpad(round(a / N; digits = 1), 6), " bytes/call")
end
