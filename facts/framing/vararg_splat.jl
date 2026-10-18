# A splatted call of many arguments: is a Vararg tail of a concrete element type a fact signature?
#
# Julia's test core.jl (issue #10981) calls `vcat(x...)` with 2·10^6 splatted arguments. Under the
# facts mode (JULIA_COMPILE_BY_FACTS=1) it does not finish. Julia compiles `vcat` for a long
# argument list at its widened signature, `vcat(::Vararg{Int})`, so inside it the arguments are a
# `Tuple{Vararg{Int}}`: not a concrete type, not a fact signature (rule 1). Every call on them is
# then a run-time site, and each run-time dispatch looks at the whole argument tuple, so the work
# grows with the square of the argument count.
#
#     julia vararg_splat.jl                              # plain
#     JULIA_COMPILE_BY_FACTS=1 julia vararg_splat.jl     # the facts mode
#
# Expected if the design admits a Vararg tail of a concrete element type as a fact signature:
# the same code in both modes (no run-time sites). Pending on that design decision; today the
# facts mode has run-time sites inside the widened specialization.
include(joinpath(@__DIR__, "..", "..", "examples", "common.jl"))
const FACTS = facts_mode()
println("julia ", VERSION, "  facts mode: ", FACTS)

splat(xs::Vector{Int}) = vcat(xs...)
const N = 3_000                         # modest: the full 2·10^6 is what does not finish
xs = collect(1:N)
check("vcat(xs...) with $N arguments computes plain Julia's value", splat(xs) == xs)

# The specialization Julia compiles for the long call: its signature, and the dynamic calls in its
# optimized code under the mode of this process (`:call` statements are run-time sites; `:invoke`
# statements are direct calls).
mi = Base.method_instance(vcat, NTuple{N,Int})       # the instance dispatch uses for the call
println("     compiled at ", mi.specTypes)
check("the specialization is at a Vararg signature (widened, not concrete)", !isconcretetype(mi.specTypes))
ci, rt = only(Base.code_typed_by_type(mi.specTypes; optimize = true))
callee(x) = x isa GlobalRef ? (isdefined(x.mod, x.name) ? getglobal(x.mod, x.name) : nothing) : x
dyn = [st for st in ci.code if Meta.isexpr(st, :call) && !(callee(st.args[1]) isa Core.Builtin)]   # generic calls: run-time sites
println("     result ", rt, "; generic calls in the optimized code: ", length(dyn))
for st in dyn[1:min(end, 5)]; println("        ", st); end
check("plain inference: no run-time sites inside the Vararg specialization", FACTS || isempty(dyn), "$(length(dyn)) generic calls")
if FACTS
    if isempty(dyn)
        check("facts mode: no run-time sites (a Vararg tail of a concrete element type is a fact signature)", true)
    else
        pending("facts mode: no run-time sites inside the Vararg specialization",
                "a design decision: a Vararg tail of a concrete element type (`Tuple{Vararg{Int}}`) as a fact signature (rule 1)",
                "$(length(dyn)) run-time sites, result $(rt)")
    end
end
# To measure after the decision (not run here: no timing in this suite):
#   - splat(collect(1:n)) for n = 10^3, 10^4, 10^5 under plain and facts: time per argument
#     (expected today: linear in plain, quadratic in facts);
#   - Julia's test core.jl #10981 (n = 2·10^6) in facts mode: finishes, and in what time.
summary()
