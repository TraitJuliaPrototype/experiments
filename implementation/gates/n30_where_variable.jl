# Gate (W-148, rewritten by W-156; compiler §6.2; traits §7.5): a `where` variable bounded by a set is the type of
# the value given: a member's, a box's. It is a static parameter as in Julia, so the method is compiled for the
# value's type, `@nospecialize` at the argument included: no instance is compiled once at the set's bound with the
# variable unknown.
using Traits
include("util.jl")
@trait X
struct A; v::Int; end        # with a field: a value is no constant the compiler could fold a call at
struct B; v::Int; end
@implement X A
@implement X B
declare_membership(Core.Dynamic{X}, X, @__MODULE__, :object, :field)
# the instances that have code
insts(fn) = sort!([string(mi.specTypes) for mi in Base.specializations(only(methods(fn))) if isdefined(mi, :cache)])
per(fn, Ts...) = sort!([string(Tuple{typeof(fn), T}) for T in Ts])

# (1) a plain member: per type, the variable its type
f(x::C) where {C <: X} = C
@assert f(A(1)) === A && f(B(2)) === B
@assert insts(f) == per(f, A, B) "per type: $(insts(f))"

# (2) a box: the variable is the box's type
d = Core.Dynamic{X}(A(1))
@assert f(d) === Core.Dynamic{X}

# (3) `@nospecialize` is Julia's: the variable is a static parameter, so the code is compiled per type
g(@nospecialize(x::C)) where {C <: X} = C
@assert g(A(1)) === A && g(B(2)) === B
@assert insts(g) == per(g, A, B) "per type: $(insts(g))"

# (4) the variable used to build a type, and in a call
mk(x::C) where {C <: X} = Vector{C}()
@assert typeof(mk(A(1))) === Vector{A} && typeof(mk(B(2))) === Vector{B}
name(::Type{A}) = :a
name(::Type{B}) = :b
nm(x::C) where {C <: X} = name(C)
@assert nm(A(1)) === :a && nm(B(2)) === :b

# (5) a dynamic call (the caller does not know the type)
function loop(xs::Vector{Any})
    out = Any[]
    for x in xs
        push!(out, f(x))
    end
    return out
end
@assert loop(Any[A(1), B(2), d]) == Any[A, B, Core.Dynamic{X}]

# (6) a second argument that fixes the variable
p(x::C, v::Vector{C}) where {C <: X} = C
@assert p(A(1), A[]) === A && p(B(2), B[]) === B

# (7) a trait with a parameter: both variables
@trait Y{T}
struct YA; v::Int; end
@implement Y{Int} YA
q(x::C) where {T, C <: Y{T}} = (C, T)
@assert q(YA(1)) === (YA, Int)
println("n30_where_variable: OK")
