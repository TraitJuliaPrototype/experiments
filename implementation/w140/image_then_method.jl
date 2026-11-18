# W-140: code in a package image, compiled where no method at a trait existed. Does a later membership
# reach it? Two orders: the method at the trait defined before the image loads, or after.
push!(LOAD_PATH, @__DIR__)
using Traits
import PlainG
@trait X
order = get(ARGS, 1, "method-first")
order == "method-first" && @eval PlainG.f(::X) = :x
@eval import PlainF
order == "method-first" || @eval PlainG.f(::X) = :x
@eval begin
    @assert PlainF.h(PlainF.S()) === :any
    @implement X PlainF.S
    r = PlainF.h(PlainF.S())
    println(order, ": after the membership h(S()) = ", r, r === :x ? "  (Julia's answer)" : "  (STALE)")
    r === :x || exit(1)
end
