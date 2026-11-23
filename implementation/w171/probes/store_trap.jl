# W-171, third part (E-544): a store into storage typed by a set (`setfield!` at a field typed X, `memoryrefset!`
# into a `Memory{X}`), compiled where the value's type is no member: inference proves the store throws and the code's
# result is `Union{}`. Once S joins X the store succeeds, but the code is kept and runs into `unreachable`.
#     julia --project=experiments/implementation store_trap.jl [stf|mrs]
using Traits
@trait X
struct S end
mutable struct MB; v::X; MB() = new(); end
stf(x) = (m = MB(); setfield!(m, :v, x); true)
mrs(x) = (Core.memoryrefset!(Core.memoryrefnew(Memory{X}(undef, 1)), x, :not_atomic, true); true)
f = (isempty(ARGS) ? "stf" : ARGS[1]) == "stf" ? stf : mrs
println("before: ", try f(S()) catch e; typeof(e) end, "  rettype ", Base.return_types(f, (S,)))
mi = only(Base.specializations(only(methods(f))))
ci = mi.cache
println("  code: rettype ", ci.rettype, ", edges ", ci.edges)
@implement X S
println("code still valid: ", ci.max_world == typemax(UInt))
println("fresh: ", ccall(:jl_isa, Cint, (Any, Any), S(), X) != 0)
println("after: ", f(S()))
