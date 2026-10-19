include("/home/hellmann/Repos/julia-trait-bound/experiments/facts/typedbench_defs.jl")
f(x) = total(x, 16)
v16 = [rand(16) for _ in 1:4]
f(v16)
fi = Base.Compiler.NativeInterpreter(Base.get_world_counter(); facts = true, owner = :facts)
src, rt = only(Base.code_typed_by_type(Tuple{typeof(f), typeof(v16)}))
println("plain f: ", src)
m0 = which(TraitWorld.conformance, Tuple{TraitWorld.As{ColTable}, typeof(v16)}); println("conformance method facts flag: ", m0.facts, " inline: ", Base.uncompressed_ast(m0).inlining)
for m in methods(Columns.total)[1:0], mi in Base.specializations(m)
    mi isa Core.MethodInstance || continue
    println(mi.specTypes)
    for (s, r) in Base.code_typed_by_type(mi.specTypes; interp = fi)
        n = count(st -> st isa Expr && st.head in (:invoke, :call), s.code)
        println("  stmts ", length(s.code), " calls/invokes ", n)
        for st in s.code; st isa Expr && st.head in (:invoke, :call) && println("    ", first(string(st), 200)); end
    end
end
