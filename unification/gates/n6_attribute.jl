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
struct Wrap{F}; f::F; end                   # the set's package's, carrying what it wraps in its type
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
# a type is own only with its parameters, recursively: one of the set's package's that carries another
# package's type in a parameter is not few and fixed, and the set's default applies to it (open issue 161)
declare_membership(Lib.Wrap, Model, @__MODULE__)
area(w::Lib.Wrap) = 1.0
@assert mkind(Lib.Wrap(c)) === :dynamic "the set's package's type carrying another package's: the default"
@assert mkind(Lib.Wrap(1)) === :compiled "the set's package's type with Julia's own parameter: per type"
@assert mkind(Lib.Wrap(Lib.Own(1.0))) === :compiled "with the set's package's parameter: per type"
@assert mkind(Lib.Wrap(sin)) === :compiled "with a function Julia defines: per type"
@assert mkind(Lib.Wrap(Lib.Wrap(c))) === :dynamic "another package's type two levels down"

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

# a cast in a call with keyword arguments (lowering L-56): through Core.kwcall, the cast's bits two
# places up; with the keywords splatted and empty, the call without them
kkind(x::Shape; scale = 1, tag = :none) = (Core.keep(x) isa Core.Dynamic ? :dynamic : :compiled, scale, tag)
kwd(x) = kkind(with_dynamic(x); scale = 3, tag = :t)
kwc(x) = kkind(compiled_for(x); scale = 3)
kwm(x) = kkind(with_dynamic(x), tag = :a)
kws(x, kw) = kkind(with_dynamic(x); kw...)
kwe(x) = kkind(with_dynamic(x);)
@assert kwd(c) === (:dynamic, 3, :t) && kwc(c) === (:compiled, 3, :none) "a cast with keywords: $(kwd(c)), $(kwc(c))"
@assert kwm(c) === (:dynamic, 1, :a)
@assert kws(c, (scale = 5,)) === (:dynamic, 5, :none) && kws(c, (;)) === (:dynamic, 1, :none)
@assert kwe(c) === (:dynamic, 1, :none)
@assert kkind(compiled_for(c); scale = 2) === (:compiled, 2, :none)

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

# the casts' names are not reserved (traits §7.6; open issue 160): a call is a cast's where the name is
# bound to Core's cast, and the ordinary call of whatever else the name is bound to
@assert lowers(:(compiled_for = 1)) && lowers(:(with_dynamic(x) = x)) && lowers(:(let compiled_for = 1; end))
@assert lowers(:(f(compiled_for(x), with_dynamic(y), z)))
@assert try compiled_for(c); false catch e; e isa ErrorException end "a cast called by its name raises"
module OwnNames               # a plain module with functions of these names
compiled_for(f) = (:own, f)
with_dynamic(x; k = 1) = (:own, x, k)
g(a, b) = (a, b)
h() = g(compiled_for(1), with_dynamic(2))
hk() = g(compiled_for(1), with_dynamic(2; k = 3))
l(compiled_for) = g(compiled_for(1), 2)                  # a local of that name
end
@assert OwnNames.h() == ((:own, 1), (:own, 2, 1)) "a module's own functions of the casts' names are called"
@assert OwnNames.hk() == ((:own, 1), (:own, 2, 3))
@assert OwnNames.l(x -> x + 1) == (2, 2) "a local of a cast's name is called"

println("n6_attribute: OK")
