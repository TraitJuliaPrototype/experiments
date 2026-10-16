using TraitWorld
const TW = TraitWorld
bc(v) = v .* 2.0 .+ 1.0
mp(v) = map(sin, v)
cp(n) = [i^2 for i in 1:n]
em(v) = map(x -> x + 1, v)        # used empty below
for (name, f, x) in (("broadcast", bc, rand(4)), ("map(sin)", mp, rand(4)), ("comprehension", cp, 4), ("empty map", em, Int[]))
    w = y -> TW._facts_call(f, y)
    f(x); w(x)
    tn = minimum(@elapsed(for _ in 1:10^5; f(x); end) for _ in 1:5) / 10^5 * 1e9
    tf = minimum(@elapsed(for _ in 1:10^5; w(x); end) for _ in 1:5) / 10^5 * 1e9
    ci = TW.facts_codeinstance(Tuple{typeof(f), typeof(x)})
    src = ccall(:jl_uncompress_ir, Ref{Core.CodeInfo}, (Any, Any, Any), ci.def.def, ci, ci.inferred)
    nrt = count(st -> Meta.isexpr(st, :call) && occursin("return_type", string(st.args[1])), src.code)
    println(rpad(name, 14), " native ", round(tn, digits = 1), " ns, policy ", round(tf, digits = 1), " ns, return_type calls left in the policy's code ", nrt,
            ", eltypes ", eltype(f(x)), " / ", eltype(w(x)))
end
