# W-4 step 3.0, follow-up: an untyped caller compiled by facts reaching an @nospecialize boundary.
# Does known_type stay false there, alone, and after typed callers have compiled the boundary inlined?
const CC = Base.Compiler
mark(b::Bool) = b ? :typed : :untyped
@eval @inline e_pos(@nospecialize(x), i::Int) = ($(Expr(:meta, :facts_boundary)); mark(CC.known_type(x)))
struct Circle; r::Float64; end
module F
Base.Experimental.@compiler_options facts=true
using ..Main: e_pos, Circle
u_pos(v::Vector{Any}) = e_pos(v[1], 1)
t_pos(c::Circle) = e_pos(c, 1)
end
p_pos(c::Circle) = e_pos(c, 1)
pu_pos(v::Vector{Any}) = e_pos(v[1], 1)
v = Any[Circle(2.0)]
order = get(ARGS, 1, "untyped-first")
if order == "plain-typed-first"
    println("plain typed, first:            ", p_pos(Circle(1.0)))
    println("facts untyped, after:          ", F.u_pos(v))
elseif order == "plain-untyped-first"
    println("plain untyped, first:          ", pu_pos(v))
    println("facts untyped, after:          ", F.u_pos(v))
elseif order == "plain-both-first"
    println("plain typed, first:            ", p_pos(Circle(1.0)))
    println("plain untyped, second:         ", pu_pos(v))
    println("facts untyped, after:          ", F.u_pos(v))
elseif order == "plain-untyped-facts-typed-first"
    println("plain untyped, first:          ", pu_pos(v))
    println("facts typed, second:           ", F.t_pos(Circle(1.0)))
    println("facts untyped, after:          ", F.u_pos(v))
elseif order == "facts-typed-plain-untyped-first"
    println("facts typed, first:            ", F.t_pos(Circle(1.0)))
    println("plain untyped, second:         ", pu_pos(v))
    println("facts untyped, after:          ", F.u_pos(v))
elseif order == "untyped-first"
    println("facts untyped, alone:          ", F.u_pos(v))
    println("facts typed, after:            ", F.t_pos(Circle(1.0)))
    println("facts untyped, again:          ", F.u_pos(v))
else
    println("facts typed, first:            ", F.t_pos(Circle(1.0)))
    println("facts untyped, after typed:    ", F.u_pos(v))
end
for m in methods(e_pos), mi in Base.specializations(m)
    mi === nothing || println("  specialization: ", mi.specTypes)
end
