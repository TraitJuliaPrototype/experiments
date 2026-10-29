# U9 self-test: a planted trait module with every case the census must find.
using TraitWorld
@trait_module module U9Lib
using TraitWorld
export Shape, Round, area, describe, g, h, k, Circle, Disk, Sq
@trait Shape begin
    area(s::Shape)::Float64
end
@trait Round <: Shape begin
    radius(s::Round)::Float64
end
describe(s::Shape) = "shape"                    # bounded, no declared result
describe(s::Round) = "round"                    # bounded on a subtrait
describe(x) = :plain                           # the untyped fallback (tagged), returns a Symbol
g(s::Shape)::Float64 = area(s)                # bounded, declared result, no fallback: MethodError for non-members
h(s::Shape, n::Int) = n                        # bounded with a plain position
h(x::Number, n::Int) = 0                       # a plain method on a declared supertype: beats the bound (C7)
k(s::Shape) = describe(s)                      # bounded code calling a function with a subtrait method
struct Circle; r::Float64; end
area(c::Circle) = pi * c.r^2
radius(c::Circle) = c.r
@implement Shape Circle
@implement Round Circle
struct Sq; a::Float64; end
area(s::Sq) = s.a^2
@implement Shape Sq
struct Disk; r::Float64; end
end
using .U9Lib
# callers in Main
c_member(c::Circle) = describe(c)                        # positive Round: fold, no guard
c_sub(s::Sq) = describe(s)                               # Shape member, not Round: subtrait guard
c_fallback(x::Int) = describe(x)                         # non-member, the untyped fallback: guard
c_fallback_loop(v::Vector{Int}) = (s = 0; for x in v; s += length(string(describe(x))); end; s)
c_methoderror(d::Disk) = g(d)                            # non-member, no method: MethodError guard
c_methoderror_core(t::Type{Int}) = describe(t)           # a type value (Core kind): no guard
c_declared(x::Float64) = h(x, 1)                          # m0 on Number (declared): no guard
c_nonconcrete(v::Vector{Any}) = describe(v[1])           # non-concrete: run-time dispatch already
c_k(s::Sq) = k(s)                                        # inside k: describe(Sq as Shape): subtrait guard
c_k2(c::Circle) = k(c)                                   # inside k: describe(Circle): Round known, fold
U9_SELFTEST_CALLS() = (c_member(Circle(1.0)), c_sub(Sq(2.0)), c_fallback(3), c_fallback_loop([1, 2]),
    (try c_methoderror(Disk(1.0)) catch; nothing end), c_methoderror_core(Int), c_declared(1.0), c_nonconcrete(Any[1]), c_k(Sq(1.0)), c_k2(Circle(1.0)))
U9_SELFTEST_CALLS()
