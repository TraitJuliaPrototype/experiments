# Gate (W-148; compiler §6.2; traits §7.4): a `where` variable bounded by a set is the value's type,
# whatever the attribute. `x::C` with `C <: X` takes the attribute as an argument typed by the set
# does. Compiled for the type, the code knows `C`. Compiled once, it reads `C` from the value when it
# runs: one instance serves every member, and gives each its own type.
using Traits
include("util.jl")
@trait X
struct A; v::Int; end        # with a field: a value is no constant the compiler could fold a call at
struct B; v::Int; end
@implement X A
@implement X B
# the instances that have code
insts(fn) = sort!([string(mi.specTypes) for mi in Base.specializations(only(methods(fn))) if isdefined(mi, :cache)])

# (1) Compiled (a plain scope's fallback): per type
f(x::C) where {C <: X} = C
@assert f(A(1)) === A && f(B(2)) === B
@assert insts(f) == sort!([string(Tuple{typeof(f), A}), string(Tuple{typeof(f), B})]) "per type: $(insts(f))"

# (2) Dynamic, by a cast: one instance, and the variable is still the value's type
g(x::C) where {C <: X} = C
dg(x) = g(with_dynamic(x))
@assert dg(A(1)) === A && dg(B(2)) === B "the where variable under Dynamic: $(dg(A(1))), $(dg(B(2)))"
@assert insts(g) == [string(Tuple{typeof(g), X})] "compiled once: $(insts(g))"

# (3) the variable used to build a type, and in a call
mk(x::C) where {C <: X} = Vector{C}()
dmk(x) = mk(with_dynamic(x))
@assert typeof(dmk(A(1))) === Vector{A} && typeof(dmk(B(2))) === Vector{B}
name(::Type{A}) = :a
name(::Type{B}) = :b
nm(x::C) where {C <: X} = name(C)
dnm(x) = nm(with_dynamic(x))
@assert dnm(A(1)) === :a && dnm(B(2)) === :b
@assert insts(nm) == [string(Tuple{typeof(nm), X})]

# (4) the variable as a bound only
h(x::C) where {C <: X} = 1
dh(x) = h(with_dynamic(x))
@assert dh(A(1)) == 1 && dh(B(2)) == 1 && insts(h) == [string(Tuple{typeof(h), X})]

# (5) a dynamic call (the caller does not know the type): the cast decides the same
function loop(xs::Vector{Any})
    out = Any[]
    for x in xs
        push!(out, g(with_dynamic(x)))
    end
    return out
end
@assert loop(Any[A(1), B(2), A(1)]) == Any[A, B, A]

# (6) a second argument that fixes the variable: compiled with it known
p(x::C, v::Vector{C}) where {C <: X} = C
dp(x, v) = p(with_dynamic(x), v)
@assert dp(A(1), A[]) === A && dp(B(2), B[]) === B

# (7) a trait with a parameter: both variables
@trait Y{T}
struct YA; v::Int; end
@implement Y{Int} YA
q(x::C) where {T, C <: Y{T}} = (C, T)
dq(x) = q(with_dynamic(x))
@assert q(YA(1)) === (YA, Int) && dq(YA(1)) === (YA, Int)
println("n30_where_variable: OK")
