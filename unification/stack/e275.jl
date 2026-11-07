# E-275: a session in either setting (compiler §2.3–§2.5). E-274's one-line work, then the policy
# of the code each kind of caller reached: user code's methods, a Base method user code calls, and a
# Base method the compiler calls dynamically. Run under the product setting and under
# JULIA_COMPILE_BY_FACTS=1:
#     <tree>/julia --startup-file=no experiments/unification/stack/e275.jl
const FACTS = 0x20   # JL_CI_FLAGS_FACTS
t0 = time()
x = sum(map(x -> x^2, 1:10)); println("sum: ", x)
f(v) = sum(v) + length(v)
println("f: ", f([1, 2, 3]))
t1 = time()

# the CodeInstances of Julia's own owner for f at `types`, with their policy bits
function policies(@nospecialize(ft), @nospecialize(types))
    match = Base._which(Tuple{ft, types...})
    mi = Base.Compiler.specialize_method(match)
    out = String[]
    isdefined(mi, :cache) || return out
    ci = mi.cache
    while true
        ci.owner === nothing && push!(out, (ci.flags & FACTS) != 0 ? "facts" : "plain")
        isdefined(ci, :next) || break
        ci = ci.next
    end
    return out
end
println("setting: ", ccall(:jl_compile_by_facts_all, Cint, ()) != 0 ? "test bed" : "product")
println("f(::Vector{Int}): ", policies(typeof(f), (Vector{Int},)))
println("sum(::Vector{Int}): ", policies(typeof(sum), (Vector{Int},)))
println("length(::Vector{Int}): ", policies(typeof(length), (Vector{Int},)))
# a method the compiler calls, reached from it only
println("getindex(::Vector{Any}, ::Int): ", policies(typeof(getindex), (Vector{Any}, Int)))
println("work: ", round(t1 - t0; digits = 3), " s")
