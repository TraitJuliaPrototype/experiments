# Small probes for the performance-phase review (plain mode, patched binary or stock).
println("VERSION ", VERSION, "  patched facts mode: ", isdefined(Base.Compiler, :FACTS_OWNER))
# 1. first run-time return_type (claim: 80-90 ms stock, 0.2 ms after 40512f64c2)
t = @elapsed Core.Compiler.return_type(cos, Tuple{Int})
println("first return_type(cos, Tuple{Int}): ", round(1000t; digits = 2), " ms")
t = @elapsed Core.Compiler.return_type(sin, Tuple{Float64})
println("second return_type(sin, Tuple{Float64}): ", round(1000t; digits = 2), " ms")
if isdefined(Base.Compiler, :FACTS_OWNER)
    CC = Base.Compiler
    m = only(methods(CC.split_call))
    println("dynamic_call method is_plain (never-by-facts module): ", ccall(:jl_method_is_plain, Cint, (Any,), m))
    println("Compiler module facts flag: ", ccall(:jl_get_module_facts, Cint, (Any,), CC))
    println("is_fact_sig(Tuple{typeof(+), Vararg{Int}}) = ", CC.is_fact_sig(Tuple{typeof(+), Vararg{Int}}),
            "  isdispatchtuple = ", isdispatchtuple(Tuple{typeof(+), Vararg{Int}}))
end
# 2. plain Julia: a varargs wrapper inside an inference cycle (recursion through an abstract type with 2
#    subtypes, i.e. "closed by accident"): is the wrapper inlined, or invoked at its compileable signature?
abstract type S end
struct A <: S; x::Float64; end
struct G <: S; kids::Vector{S}; end
@inline wrap(f::F, r, args...) where {F} = f(r, args...)
visit(a::A, h::Float64, k::Int) = a.x + h
function visit(g::G, h::Float64, k::Int)
    for c in g.kids
        h = wrap(visit, c, h, k)
    end
    return h
end
g = G(S[A(1.0), G(S[A(2.0)])])
visit(g, 0.0, 1)
ci = code_typed(visit, (G, Float64, Int))[1][1]
for s in ci.code
    s isa Expr && s.head === :invoke && println("invoke target: ", s.args[1] isa Core.CodeInstance ? s.args[1].def.specTypes : s.args[1])
    s isa Expr && s.head === :call && println("dynamic call: ", s.args[1])
end
println("specializations of wrap: ")
for mi in Base.specializations(only(methods(wrap)))
    println("   ", mi.specTypes)
end
