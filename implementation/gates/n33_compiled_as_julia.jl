# Gate (W-156; compiler §2.1, §6.2, §6.9; traits §7.1, §7.5, §7.7): an argument is compiled as Julia compiles it. At a trait
# argument a plain member's call runs the instance for its type, a box's the instance at the box (one per set
# instance), and an argument declared `@nospecialize` the instance at the declared set; passed on from there it is a
# run-time site. Nothing beside the values decides: neither the call's site (a static call, a dynamic call) nor the
# method's module. No cast, no `keep`, no `Core.attributed_call`: the names are no part of Core, lowering knows none.
# And the kept forms are Core's: the box `Dynamic{X}` and the wrapper `Compiled{T}`, with their constructors (§6.9).
# It replaces `not-in-force/n6_attribute.jl`, which pinned the attribute.
using Traits
include("util.jl")
lowers(ex) = !Meta.isexpr(Meta.lower(@__MODULE__, ex), :error)
insts(fn) = sort!(unique([string(mi.specTypes.parameters[2]) for m in methods(fn) for mi in Base.specializations(m)
                          if mi !== nothing && isdefined(mi, :cache)]))

@trait Shape
struct Circle; r::Float64; end
struct Square; s::Float64; end
@implement Shape Circle
@implement Shape Square
declare_membership(Core.Dynamic{Shape}, Shape, @__MODULE__, :object, :field)
c, s = Circle(1.0), Square(2.0)
d = Core.Dynamic{Shape}(c)

# (1) a plain member, at a static call and at a dynamic call: compiled for its type
s1(x::Shape) = 1
st1(x::Circle) = s1(x)
dy1(v::Vector{Any}) = Base.invokelatest(s1, v[1])   # a call the runtime dispatches
@assert st1(c) == 1 && dy1(Any[s]) == 1
@assert insts(s1) == ["Circle", "Square"] "per type: $(insts(s1))"

# (2) the box: one instance at the box, for every member
s2(x::Shape) = 1
@assert s2(d) == 1 && s2(Core.Dynamic{Shape}(s)) == 1 && Base.invokelatest(s2, d) == 1
@assert insts(s2) == ["Core.Dynamic{Shape}"] "at the box: $(insts(s2))"

# (3) `@nospecialize`: at the declared set; passed on, a run-time site, its callee compiled per type
@noinline s3b(x::Shape) = x  # (its result depends on the value: the call is not folded away)
s3(@nospecialize(x::Shape)) = s3b(x)
@assert s3(c) === c && s3(s) === s
@assert insts(s3) == ["Shape"] "at the set: $(insts(s3))"
@assert issubset(["Circle", "Square"], insts(s3b)) "passed on, compiled for each type when it runs: $(insts(s3b))"
@assert any(st -> Meta.isexpr(st, :call), first(only(code_typed(s3, (Shape,)))).code) "a run-time site"

# (4) `@specialize` is Julia's
s4(@specialize(x::Shape)) = 1
@assert s4(c) == 1 && s4(s) == 1 && insts(s4) == ["Circle", "Square"]

# (5) the module decides nothing: a module compiled by facts compiles per type too, and the options that chose an
# attribute are refused
module M5
Base.Experimental.@compiler_options facts=true
import ..Shape
s5(x::Shape) = 1
end
@assert M5.s5(c) == 1 && M5.s5(s) == 1 && insts(M5.s5) == ["Circle", "Square"] "per type: $(insts(M5.s5))"
@assert all(o -> try macroexpand(Main, :(Base.Experimental.@compiler_options $(o)=true)); false catch; true end, (:dynamic, :first_seen))

# (6) no cast, no keep, no attributed call: ordinary names
@assert !any(n -> isdefined(Core, n), (:compiled_for, :with_dynamic, :attributed_call, :keep, :_cast_compiled))
@assert lowers(:(f(compiled_for(x), with_dynamic(y), z)))
@assert !occursin("attributed_call", string(Meta.lower(@__MODULE__, :(f(compiled_for(x)); g(with_dynamic(y); k = 1)))))
module OwnNames               # a plain module with functions of these names
compiled_for(f) = (:own, f)
with_dynamic(x; k = 1) = (:own, x, k)
g(a, b) = (a, b)
h() = g(compiled_for(1), with_dynamic(2))
hk() = g(compiled_for(1), with_dynamic(2; k = 3))
end
@assert OwnNames.h() == ((:own, 1), (:own, 2, 1)) && OwnNames.hk() == ((:own, 1), (:own, 2, 3))

# (7) the kept forms in Core (compiler §6.9, C-113): the box and the wrapper are Core's structs
@assert isdefined(Core, :Compiled) && Core.Compiled{Circle} isa DataType && fieldnames(Core.Compiled) == (:object,)
w = Core.Compiled(c)
@assert w isa Core.Compiled{Circle} && getfield(w, :object) === c
@assert Core.Compiled(w) === w "a wrapper is itself"
@assert getfield(Core.Compiled(d), :object) === c && Core.Compiled(d) isa Core.Compiled{Circle} "a box gives its object wrapped"
@assert Core.Dynamic{Shape}(d) === d "a box of X is itself"
@assert getfield(Core.Dynamic{Shape}(w), :object) === c "a wrapper gives its object boxed"
@assert (try Core.Dynamic{Shape}(1); false catch e; e isa TypeError end) "a value that is not a member: new's field test"
@trait Sub
@trait Other
declare_membership(Sub, Shape, @__MODULE__)               # Sub is a subset of Shape
@implement Sub Circle
@implement Other Circle
declare_membership(Core.Dynamic{Sub}, Sub, @__MODULE__, :object, :field)
declare_membership(Core.Dynamic{Other}, Other, @__MODULE__, :object, :field)
@assert Core.Dynamic{Shape}(Core.Dynamic{Sub}(c)) isa Core.Dynamic{Shape} && getfield(Core.Dynamic{Shape}(Core.Dynamic{Sub}(c)), :object) === c "a box of a subset gives its object boxed"
@assert (try Core.Dynamic{Shape}(Core.Dynamic{Other}(c)); false catch e; e isa TypeError end) "a box of another set is no member"
@trait Col{T}
@assert (try Core.Dynamic{Col}(c); false catch e; e isa ArgumentError end) "a bare parametric set"

println("n33_compiled_as_julia: OK")
