using TraitWorld
f(x) = x + 1
T = Base.inferencebarrier(Tuple{typeof(f), Int})::DataType
t = @elapsed Base._return_type(T)
println("with TraitWorld loaded, first run-time return_type: ", round(t * 1000; digits = 1), " ms")
