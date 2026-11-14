# W-145, part 1 (G-2, as a control; W-17): what a call through a trait costs beside its plain twin.
# Idiomatic trait code (a trait module, TraitWorld) and a plain module with the same functions.
# Each row: a loop of N calls, the minimum of 7 runs, in ns a call. Not interop.
#     julia --project=<TraitWorld-unified> calls.jl [N]
using TraitWorld

module T                                       # the trait form
using TraitWorld
@trait_module
@trait Shape begin
    area(s::Shape)::Float64
end
@trait Model begin                             # a trait whose members are compiled once by default
    @default_dynamic
    rate(m::Model, u::Float64)::Float64
end
struct Circle; r::Float64; end
struct Square; a::Float64; end
area(c::Circle) = 3.0 * c.r * c.r
area(s::Square) = s.a * s.a
@implement Shape Circle
@implement Shape Square
scaled(s::Shape) = 2.0 * area(s)               # a method at the trait
step(m::Model, u::Float64) = u + 1e-9 * rate(m, u)
struct Holder; s::Dynamic{Shape}; end          # a value kept by its trait in a field
apply(f::Callable{Tuple{Float64}, Float64}, x::Float64) = f(x)
end

module U                                       # a user's member of Model, in another module
using TraitWorld
import ..T: Model, rate
struct Decay; k::Float64; end
rate(d::Decay, u::Float64) = -d.k * u
@implement Model Decay
end

module P                                       # the plain twin
abstract type Shape end
struct Circle <: Shape; r::Float64; end
struct Square <: Shape; a::Float64; end
area(c::Circle) = 3.0 * c.r * c.r
area(s::Square) = s.a * s.a
scaled(s) = 2.0 * area(s)
struct Decay; k::Float64; end
rate(d::Decay, u::Float64) = -d.k * u
step(m, u::Float64) = u + 1e-9 * rate(m, u)
struct Holder; s::Shape; end                   # an abstract field
apply(f, x::Float64) = f(x)
end

const N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 10^7
const SINK = Ref(0.0)
ns(h, args...; n = N) = minimum(@elapsed(SINK[] += h(args..., n)) for _ in 1:7) / n * 1e9

# 1. an operation at a known type
function op_t(c::T.Circle, n); s = 0.0; for _ in 1:n; s += T.area(c); end; s; end
function op_p(c::P.Circle, n); s = 0.0; for _ in 1:n; s += P.area(c); end; s; end
# 2. a method at the trait, called at a known type (compiled for the type: Julia's default)
function meth_t(c::T.Circle, n); s = 0.0; for _ in 1:n; s += T.scaled(c); end; s; end
function meth_p(c::P.Circle, n); s = 0.0; for _ in 1:n; s += P.scaled(c); end; s; end
# 3. a trait whose default is Dynamic: as it is (compiled once), and with the cast compiled_for
function dyn_default(d::U.Decay, n); u = 1.0; for _ in 1:n; u = T.step(d, u); end; u; end
function dyn_cast(d::U.Decay, n); u = 1.0; for _ in 1:n; u = T.step(compiled_for(d), u); end; u; end
function dyn_plain(d::P.Decay, n); u = 1.0; for _ in 1:n; u = P.step(d, u); end; u; end
# 4. elements known by their trait: a Vector{Shape} of two member types, beside plain Julia's
#    Vector of the abstract type and of the Union
function vec_t(xs::Vector{T.Shape}, n); s = 0.0; m = length(xs); for i in 1:n; s += T.area(xs[mod1(i, m)]); end; s; end
function vec_p(xs::Vector{P.Shape}, n); s = 0.0; m = length(xs); for i in 1:n; s += P.area(xs[mod1(i, m)]); end; s; end
function vec_u(xs::Vector{Union{P.Circle, P.Square}}, n); s = 0.0; m = length(xs); for i in 1:n; s += P.area(xs[mod1(i, m)]); end; s; end
function vec_c(xs::Vector{P.Circle}, n); s = 0.0; m = length(xs); for i in 1:n; s += P.area(xs[mod1(i, m)]); end; s; end
# 5. a field typed Dynamic{Shape}, beside a field of the abstract type
function fld_t(h::T.Holder, n); s = 0.0; for _ in 1:n; s += T.area(h.s); end; s; end
function fld_p(h::P.Holder, n); s = 0.0; for _ in 1:n; s += P.area(h.s); end; s; end
# 6. a function argument declared Callable: compiled for the function, compiled once, plain
f(x::Float64) = x * 1.0000001
function call_c(x::Float64, n); for _ in 1:n; x = T.apply(compiled_for(f), x); end; x; end
function call_d(x::Float64, n); for _ in 1:n; x = T.apply(with_dynamic(f), x); end; x; end
function call_p(x::Float64, n); for _ in 1:n; x = P.apply(f, x); end; x; end

tc, pc = T.Circle(1.0), P.Circle(1.0)
txs = T.Shape[isodd(i) ? T.Circle(1.0) : T.Square(1.0) for i in 1:64]
pxs = P.Shape[isodd(i) ? P.Circle(1.0) : P.Square(1.0) for i in 1:64]
uxs = Union{P.Circle, P.Square}[isodd(i) ? P.Circle(1.0) : P.Square(1.0) for i in 1:64]
cxs = [P.Circle(1.0) for i in 1:64]
th, ph = T.Holder(Dynamic{T.Shape}(tc)), P.Holder(pc)
td, pd = U.Decay(0.5), P.Decay(0.5)

rows = [
    ("1 operation at a known type",                 "trait",                      () -> ns(op_t, tc)),
    ("1 operation at a known type",                 "plain",                      () -> ns(op_p, pc)),
    ("2 method at the trait, known type",           "trait",                      () -> ns(meth_t, tc)),
    ("2 method at the trait, known type",           "plain",                      () -> ns(meth_p, pc)),
    ("3 trait with a Dynamic default",              "trait, as it is (once)",     () -> ns(dyn_default, td)),
    ("3 trait with a Dynamic default",              "trait, compiled_for",        () -> ns(dyn_cast, td)),
    ("3 trait with a Dynamic default",              "plain",                      () -> ns(dyn_plain, pd)),
    ("4 element of a vector, two types",            "trait, Vector{Shape}",       () -> ns(vec_t, txs)),
    ("4 element of a vector, two types",            "plain, Vector{abstract}",    () -> ns(vec_p, pxs)),
    ("4 element of a vector, two types",            "plain, Vector{Union}",       () -> ns(vec_u, uxs)),
    ("4 element of a vector, two types",            "plain, Vector{Circle} (one type)", () -> ns(vec_c, cxs)),
    ("5 a field",                                   "trait, ::Dynamic{Shape}",    () -> ns(fld_t, th)),
    ("5 a field",                                   "plain, ::abstract",          () -> ns(fld_p, ph)),
    ("6 a function argument",                       "Callable, compiled_for(f)",  () -> ns(call_c, 1.0)),
    ("6 a function argument",                       "Callable, with_dynamic(f)",  () -> ns(call_d, 1.0)),
    ("6 a function argument",                       "plain",                      () -> ns(call_p, 1.0)),
]
# the answers agree
@assert op_t(tc, 10) == op_p(pc, 10) && meth_t(tc, 10) == meth_p(pc, 10)
@assert dyn_default(td, 10) == dyn_cast(td, 10) == dyn_plain(pd, 10)
@assert vec_t(txs, 100) == vec_p(pxs, 100) == vec_u(uxs, 100)
@assert fld_t(th, 10) == fld_p(ph, 10) && call_c(1.0, 10) == call_d(1.0, 10) == call_p(1.0, 10)
for (_, _, r) in rows; r(); end                # warm
println("| Row | Form | ns a call |"); println("|---|---|---|")
for (a, b, r) in rows
    println("| ", a, " | ", b, " | ", round(r(); digits = 2), " |")
end
