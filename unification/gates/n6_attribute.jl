# Gate (W-111; compiler §6.3, §6.9; traits §7.4–§7.8): each trait argument's attribute, decided by the
# steps of traits §7.5, chooses the instance that runs: compiled once at the set (`Dynamic`) or for the
# value's type (`Compiled`). `Core.keep` shows which: the argument in an instance compiled for its
# type, a `Dynamic{X}` of it in one compiled once. Results are identical under every attribute.
using Traits
include("util.jl")

dyn_default!(T, a) = ccall(:jl_set_default_attribute, Cvoid, (Any, Cint), T, a)
lowers(ex) = !Meta.isexpr(Meta.lower(@__MODULE__, ex), :error)

module Lib                                  # the set's package
using Traits
@trait Shape
@trait Model                                # its default: Dynamic (step 4)
struct Own; r::Float64; end                 # a member of the set's own package
end
using .Lib: Shape, Model
dyn_default!(Model, 2)

module User                                 # another package's members
struct Circle; r::Float64; end
struct Square; s::Float64; end
end
using .User: Circle, Square
for T in (Circle, Square, Lib.Own, Int)
    declare_membership(T, Shape, @__MODULE__)
    declare_membership(T, Model, @__MODULE__)
end
area(c::Circle) = 3.0 * c.r^2
area(s::Square) = s.s^2
area(o::Lib.Own) = o.r
area(i::Int) = Float64(i)

# which instance runs, at a trait argument with no attribute of its own
kind(x::Shape) = Core.keep(x) isa Core.Dynamic ? :dynamic : :compiled
mkind(x::Model) = Core.keep(x) isa Core.Dynamic ? :dynamic : :compiled
marea(x::Model) = area(x)
c, s = Circle(1.0), Square(2.0)

# step 5 (no option): Compiled, Julia's rule for an abstract type
@assert kind(c) === :compiled && kind(s) === :compiled

# step 4: the set's default, but not for Julia's own types or the set's package's
@assert mkind(c) === :dynamic && mkind(s) === :dynamic
@assert mkind(1) === :compiled "a type of Julia's own: per type"
@assert mkind(Lib.Own(1.0)) === :compiled "a type of the set's package: per type"
@assert marea(c) == area(c) && marea(s) == area(s)

# step 3: the method's `@nospecialize` and `@specialize` at the argument; the module's `dynamic`
nkind(@nospecialize(x::Shape)) = Core.keep(x) isa Core.Dynamic ? :dynamic : :compiled
skind(@specialize(x::Model)) = Core.keep(x) isa Core.Dynamic ? :dynamic : :compiled
@assert nkind(c) === :dynamic && skind(c) === :compiled
module DynMod
Base.Experimental.@compiler_options dynamic=true
import ..Shape
kind(x::Shape) = Core.keep(x) isa Core.Dynamic ? :dynamic : :compiled
end
@assert DynMod.kind(c) === :dynamic

# step 5 with `first_seen`: what the caller knows
module First
Base.Experimental.@compiler_options first_seen=true
import ..Shape, ..Circle
kind(x::Shape) = Core.keep(x) isa Core.Dynamic ? :dynamic : :compiled
static(c::Circle) = kind(c)                 # the caller knows the type: Compiled
dynamic(v::Vector{Any}) = kind(v[1])        # it does not: Dynamic
end
@assert First.static(c) === :compiled
@assert First.dynamic(Any[c]) === :dynamic

# step 1: a cast at the call, over every default
@assert mkind(compiled_for(c)) === :compiled
@assert kind(with_dynamic(c)) === :dynamic
castc(x) = mkind(compiled_for(x))
castd(x) = kind(with_dynamic(x))
@assert castc(c) === :compiled && castd(c) === :dynamic
@assert castc(s) === :compiled && castd(s) === :dynamic        # the runtime's cache, a second type
d = Core.Dynamic{Shape}(c)
@assert Core.Dynamic{Shape}(d) === d || Core.Dynamic{Shape}(d).object === c
unwrapped(x) = kind(compiled_for(x))
declare_membership(Core.Dynamic{Shape}, Shape, @__MODULE__, :object, :field)
@assert unwrapped(d) === :compiled "compiled_for of a Dynamic passes its object"

# step 2: the attribute the value carries
#   an argument passed on keeps the attribute of the instance it is in
passn(@nospecialize(x::Shape)) = kind(x)    # compiled once: passes Dynamic
passc(x::Model) = nkind(x)                  # compiled for the type: passes Compiled over @nospecialize
@assert passn(c) === :dynamic
@assert skind(c) === :compiled && passc(1) === :compiled
#   a Dynamic{X} is Dynamic: its type is one for every member
@assert kind(d) === :dynamic
#   at a run-time site of code compiled once, the call passes Dynamic on (Core.attributed_call)
module Rt
Base.Experimental.@compiler_options facts=true
import ..Shape, ..kind
pass(@nospecialize(x::Shape)) = kind(x)
end
@assert Rt.pass(c) === :dynamic

# keep: Dynamic{X} of the argument where compiled once, the argument where compiled for its type
kd(@nospecialize(x::Shape)) = Core.keep(x)
kc(x::Shape) = Core.keep(x)
@assert kd(c) isa Core.Dynamic{Shape} && kd(c).object === c
@assert kc(c) === c

# identical results under every attribute
total(xs) = sum(area, xs)
@assert marea(c) + marea(s) == total([c, s]) == area(c) + area(s)

# the casts are reserved names, written as an argument of the call they decide
@assert !lowers(:(compiled_for(x)))
@assert !lowers(:(y = with_dynamic(x)))
@assert !lowers(:(compiled_for = 1))
@assert !lowers(:(with_dynamic(x) = x))
@assert !lowers(:(let compiled_for = 1; end))
@assert lowers(:(f(compiled_for(x), with_dynamic(y), z)))

println("n6_attribute: OK")
