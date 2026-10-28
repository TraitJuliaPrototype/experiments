f(x) = x + 1
T = Base.inferencebarrier(Tuple{typeof(f), Int})::DataType
t = @elapsed Base._return_type(T)
println("first run-time return_type: ", round(t * 1000; digits = 1), " ms")
T2 = Base.inferencebarrier(Tuple{typeof(f), Float64})::DataType
t = @elapsed Base._return_type(T2)
println("second: ", round(t * 1000; digits = 1), " ms")
