# Plain Julia: the same varargs wrapper in a cycle, compiled by the RUNTIME path first (as a program would).
println("VERSION ", VERSION, "  patched facts mode: ", isdefined(Base.Compiler, :FACTS_OWNER))
t = @elapsed Core.Compiler.return_type(cos, Tuple{Int})
println("first return_type(cos, Tuple{Int}): ", round(1000t; digits = 2), " ms")
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
n = 10^5
big = G(S[isodd(i) ? A(1.0) : G(S[A(2.0)]) for i in 1:n])
visit(big, 0.0, 1)                                     # runtime compilation meets the cycle
a = @allocated visit(big, 0.0, 1)
t = minimum(@elapsed(visit(big, 0.0, 1)) for _ in 1:5)
println("visit (runtime-compiled) over ", n, " kids: ", round(1e6t; digits = 1), " us, ", a, " bytes allocated")
println("specializations of wrap:")
for mi in Base.specializations(only(methods(wrap)))
    println("   ", mi.specTypes)
end
ci = code_typed(visit, (G, Float64, Int))[1][1]
for s in ci.code
    if s isa Expr && s.head === :invoke
        tgt = s.args[1]
        println("invoke target (code_typed after run): ", tgt isa Core.CodeInstance ? tgt.def.specTypes : tgt isa Core.MethodInstance ? tgt.specTypes : tgt)
    end
end
visit2(a::A, h::Float64, k::Int) = a.x + h
function visit2(g::G, h::Float64, k::Int)
    for c in g.kids
        h = visit2(c, h, k)
    end
    return h
end
visit2(big, 0.0, 1)
a2 = @allocated visit2(big, 0.0, 1)
t2 = minimum(@elapsed(visit2(big, 0.0, 1)) for _ in 1:5)
println("visit2 (no wrapper) over ", n, " kids: ", round(1e6t2; digits = 1), " us, ", a2, " bytes allocated")
