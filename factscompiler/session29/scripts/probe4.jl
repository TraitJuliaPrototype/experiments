# A run-time return_type that inference cannot fold: the entry _return_type(::NativeInterpreter, ::DataType).
println("VERSION ", VERSION, "  patched facts mode: ", isdefined(Base.Compiler, :FACTS_OWNER))
const F = Ref{Any}(cos)
f() = Core.Compiler.return_type(F[], Tuple{Int})          # F[]::Any: no fold
t = @elapsed f()
println("first run-time return_type (unfoldable): ", round(1000t; digits = 2), " ms")
t = @elapsed f()
println("second: ", round(1000t; digits = 3), " ms")
F[] = sin
t = @elapsed Core.Compiler.return_type(F[], Tuple{Float64})
println("third, another signature: ", round(1000t; digits = 3), " ms")
g() = map(x -> x + 1, Int[])
t = @elapsed g()
println("map over an empty Vector{Int} (first): ", round(1000t; digits = 2), " ms")
