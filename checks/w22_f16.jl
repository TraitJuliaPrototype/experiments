# F-16 after W-22: under `all` the default interpreter is the facts owner's
using Static
SI = Static.StaticInt{2}
C = Base.Compiler
println("default owner ", C.NativeInterpreter().owner, " facts ", C.NativeInterpreter().facts)
for (n, f, tt) in (("promote_type(Int, SI)", Base.promote_type, (Type{Int}, Type{SI})), ("*(Int, SI)", *, (Int, SI)))
    println(rpad(n, 24), "default: ", Base.return_types(f, tt)[1], "   facts/:facts: ",
            Base.return_types(f, tt; interp = C.NativeInterpreter(; owner = C.FACTS_OWNER))[1])
end
g(x) = promote_type(Int, typeof(x))
println("a neutral caller's inferred result: ", Base.return_types(g, (SI,))[1], "; value ", g(SI()))
