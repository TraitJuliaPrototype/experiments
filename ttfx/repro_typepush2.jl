# Which interpreter creates the exact-type specialization: infer f() with the facts and the plain interpreter.
nohash(f) = [mi.specTypes for m in methods(f) for mi in Base.specializations(m) if (u = Base.unwrap_unionall(mi.specTypes); u isa DataType && u.hash == 0)]
const V = Type[]
for (facts, T) in ((true, Union{Tuple{Int32, Float64}, Tuple{Int32}}), (false, Union{Tuple{Int16, Float64}, Tuple{Int16}}))
    f = @eval () -> push!(V, $T)
    b = length(nohash(Base._push!)); bp = length(nohash(Base.push!))
    Base.code_typed(f, (); interp = Base.Compiler.NativeInterpreter(; facts))
    println("facts = ", facts, ": push! specializations without hash +", length(nohash(Base.push!)) - bp, ", _push! +", length(nohash(Base._push!)) - b)
end
