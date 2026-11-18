# E-407 (W-151; GT-19): the forwarder's box made three ways, each forwarder written by hand at E-402's trait
# (a `Model` that erases by default, a member `Decay` of another module), the kept-form method not inlined:
#   jl_new_struct  the prototype's (a runtime call: always on the heap)
#   new_gen        the `:new` expression in a function generated per member type (no constructor, no test)
#   new_eval       the `:new` expression in a method with `@nospecialize(t)`, inlined into the forwarder
#   new_declared   new_gen for a member by its definition (`struct Decay2 <: Model`), whose subtyping Julia's
#                  codegen decides without a membership: what the box costs where the member test folds
#   once_noinline  (W-160) the forwarder the definition makes (`step2(m::Model, u)` in T, julia `next` with the
#                  library's expansion hook): `@nospecialize` at the trait, compiled once, the box by `new` (its
#                  field test holds by the declared type); the call kept from inlining it (`@noinline` at the call)
#   once_inlined   (W-160) the same forwarder inlined into a caller that knows the member's type (`@inline` at the
#                  call): the test holds through the membership's entry, decided where inference records the entry
# Per variant: ns a call (E-402's harness: 10^7 calls, the minimum of 7 runs), bytes allocated a call, and the
# forwarder's LLVM IR (`code_llvm`) to `logs/variants-ir-<variant>.ll`.
#     julia --project=<TraitWorld> variants.jl
using TraitWorld, InteractiveUtils
module T
using TraitWorld
@trait_module first_seen = false
@trait Model begin
    @default_dynamic
    rate(m::Model, u::Float64)::Float64
end
# the kept-form method, as `@erasing` makes it, kept from inlining so the box crosses a call
@noinline step(m::Union{Dynamic{<:Model}, Compiled{<:Model}}, u::Float64) = u + 1e-9 * rate(m, u)
# as written, at the trait: on `next` the definition makes the method at the kept forms and its forwarder
@noinline step2(m::Model, u::Float64) = u + 1e-9 * rate(m, u)
end
module U
using TraitWorld
import ..T: Model, rate
struct Decay; k::Float64; end
rate(d::Decay, u::Float64) = -d.k * u
@implement Model Decay
end
module U2
using TraitWorld
import ..T: Model, rate
struct Decay2 <: Model; k::Float64; end
rate(d::Decay2, u::Float64) = -d.k * u
@implement Model Decay2
end
const D = Dynamic{T.Model}
# the three boxes
@inline box_ccall(x) = ccall(:jl_new_struct, Any, (Any, Any...), D, x)::D
@generated box_gen(x) = Expr(:new, D, :x)
@eval @inline box_eval(@nospecialize(t)) = $(Expr(:new, D, :t))
# the forwarders, per member type (`@specialize`), each boxing and calling the kept-form method
fw_ccall(m::U.Decay, u::Float64) = T.step(box_ccall(m), u)
fw_gen(m::U.Decay, u::Float64) = T.step(box_gen(m), u)
fw_eval(m::U.Decay, u::Float64) = T.step(box_eval(m), u)
fw_declared(m::U2.Decay2, u::Float64) = T.step(box_gen(m), u)
call_once_ni(m::U.Decay, u::Float64) = @noinline T.step2(m, u)
call_once_in(m::U.Decay, u::Float64) = @inline T.step2(m, u)
loop(fw, d, n) = (u = 1.0; for _ in 1:n; u = fw(d, u); end; u)
held(b, n) = (u = 1.0; for _ in 1:n; u = T.step(b, u); end; u)
# bytes a call, measured in a function compiled for the argument types (no boxing at the top level)
alloc_of(fw, x) = (fw(x, 1.0); @allocated fw(x, 1.0))
const N = 10^7
const SINK = Ref(0.0)
ns(h, args...) = minimum(@elapsed(SINK[] += h(args..., N)) for _ in 1:7) / N * 1e9
d = U.Decay(0.5)
@assert loop(fw_ccall, d, 10) == loop(fw_gen, d, 10) == loop(fw_eval, d, 10) == held(D(d), 10) == loop(call_once_ni, d, 10) == loop(call_once_in, d, 10)
d2 = U2.Decay2(0.5)
for (name, fw, x) in (("jl_new_struct", fw_ccall, d), ("new_gen", fw_gen, d), ("new_eval", fw_eval, d), ("new_declared", fw_declared, d2), ("once_noinline", call_once_ni, d), ("once_inlined", call_once_in, d))
    loop(fw, x, 10); fw(x, 1.0)
    a = alloc_of(fw, x)
    println(rpad(name, 16), "ns a call ", round(ns(loop, fw, x); digits = 2), "   bytes a call ", a)
    open(joinpath(get(ENV, "IRDIR", joinpath(@__DIR__, "logs")), "variants-ir-$name.ll"), "w") do io
        code_llvm(io, fw, (typeof(x), Float64); debuginfo = :none)
        fw === call_once_ni && code_llvm(io, T.step2, (T.Model, Float64); debuginfo = :none)   # the forwarder
    end
end
b = D(d); held(b, 10)
println(rpad("a box held", 16), "ns a call ", round(ns(held, b); digits = 2), "   bytes a call ", alloc_of(T.step, b))
open(joinpath(get(ENV, "IRDIR", joinpath(@__DIR__, "logs")), "variants-ir-kept-form.ll"), "w") do io
    code_llvm(io, T.step, (D, Float64); debuginfo = :none)
end
