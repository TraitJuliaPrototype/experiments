# What an entry method compiled ahead invalidates (traits T-24, lowering L-22).
#
# While a package that declares `@implement X T` is precompiled, TraitWorld adds an entry method
# for `T` itself to each tabled entry whose position needs `X` (`_ahead_entry!`, TraitWorld/src/ahead.jl):
# `f(a1::T, …) = invoke(f, Tuple{Any, …}, a1, …)`. It is a new method of the library's function, so
# Julia invalidates what a new method at `T` intersects. This script calls `_ahead_entry!` directly in
# a session (plain mode, the product setting), for a trait module `Lib` with the entry
# `total(s::Shape)` and a new conforming type `B`, and logs the invalidations:
#   - a plain caller `pc()` that calls `Lib.total(x)` on the elements of a `Vector{Any}` is invalidated;
#   - so is the entry's own untyped specialization, `total(::Any)`;
#   - the results stay correct.
# Code compiled by facts is not affected: its calls at abstract types are run-time sites without edges.
#
# Run from TraitWorld/ (one Julia process at a time; the machine is shared):
#   cd TraitWorld && ../julia-1.13/julia --project=. --startup-file=no ../experiments/docs-examples/ahead_invalidation.jl
using TraitWorld
toplevel(ex) = Core.eval(Main, Expr(:toplevel, ex.args...))
toplevel(quote
    @trait_module module Lib
    using TraitWorld
    export Shape, area, total
    @trait Shape begin
        area(s::Shape)::Float64
    end
    total(s::Shape) = 2.0 * area(s)
    end
    using .Lib
    struct A; x::Float64; end
    Lib.area(a::A) = a.x
    @implement Shape A
    struct B; x::Float64; end
    Lib.area(b::B) = 3b.x
    @implement Shape B
end)
const XS = Any[A(1.0), A(2.0)]
pc() = (s = 0.0; for x in XS; s += Lib.total(x)::Float64; end; s)     # a plain caller at an abstract argument
pc2(x) = Lib.total(x)                                                  # and one specialized at Any
println("before: ", pc(), " ", pc2(XS[1]))
ms = [m for m in methods(Lib.total)]
println("methods of total before: ", length(ms), " ", [m.sig for m in ms])
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
n = TraitWorld._ahead_entry!(Main, B, Lib.total, 1, 1)
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
println("ahead entries compiled: ", n, "; methods of total after: ", length(methods(Lib.total)))
inv = [x for x in log if x isa Core.MethodInstance]
println("invalidated MethodInstances: ", length(inv))
for x in inv; println("  ", x); end
println("after: ", pc(), " ", pc2(XS[1]))
