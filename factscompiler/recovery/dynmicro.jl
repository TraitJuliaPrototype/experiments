using TraitWorld, BenchmarkTools
abstract type PShape end
struct PSq <: PShape; a::Float64; end
struct PCi <: PShape; r::Float64; end
struct PTr <: PShape; b::Float64; end
struct PRe <: PShape; w::Float64; end
parea(s::PSq) = s.a^2; parea(s::PCi) = 3.0 * s.r^2; parea(s::PTr) = 0.5 * s.b^2; parea(s::PRe) = 2.0 * s.w
psum(v) = (s = 0.0; for x in v; s += parea(x); end; s)
abstract type QShape end
struct QSq <: QShape; a::Float64; end
struct QCi <: QShape; r::Float64; end
qarea(s::QSq) = s.a^2; qarea(s::QCi) = 3.0 * s.r^2
qsum(v) = (s = 0.0; for x in v; s += qarea(x); end; s)
Core.eval(Main, Expr(:toplevel, :(@trait_module module TS
using TraitWorld
export Shape, area, tsum, mk
@trait Shape{R} begin
    area(r::R)::Float64
end
struct Sq; a::Float64; end
struct Ci; r::Float64; end
struct Tr; b::Float64; end
struct Re; w::Float64; end
@implement Shape{Sq} begin area(s) = s.a^2 end
@implement Shape{Ci} begin area(s) = 3.0 * s.r^2 end
@implement Shape{Tr} begin area(s) = 0.5 * s.b^2 end
@implement Shape{Re} begin area(s) = 2.0 * s.w end
tsum(v::Vector{Dynamic{Shape}}) = (s = 0.0; for d in v; s += area(d); end; s)
mk(k::Int, x::Float64) = k == 1 ? Dynamic{Shape}(Sq(x)) : k == 2 ? Dynamic{Shape}(Ci(x)) : k == 3 ? Dynamic{Shape}(Tr(x)) : Dynamic{Shape}(Re(x))
end)))
n = parse(Int, get(ENV, "N", "1000000"))
p2 = QShape[isodd(i) ? QSq(1.0) : QCi(1.0) for i in 1:n]
p4 = PShape[(PSq, PCi, PTr, PRe)[i % 4 + 1](1.0) for i in 1:n]
d2 = Dynamic{TS.Shape}[TS.mk(isodd(i) ? 1 : 2, 1.0) for i in 1:n]
d4 = Dynamic{TS.Shape}[TS.mk(i % 4 + 1, 1.0) for i in 1:n]
for (l, f, v) in (("plain, 2 methods", qsum, p2), ("plain, 4 methods", psum, p4), ("Dynamic, 2 types", TS.tsum, d2), ("Dynamic, 4 types", TS.tsum, d4))
    println(rpad(l, 18), round(@belapsed($f($v)) / n * 1e9, digits = 2), " ns per element")
end
