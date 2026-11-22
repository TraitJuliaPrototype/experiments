# W-19, P10 and P18: the first call in a fresh session of a run-time `return_type` query and of
# `Base.infer_return_type`, against their second call.
#   julia --startup-file=no first_calls.jl rt|irt
what = ARGS[1]
if what == "rt"
    fs = Any[cos, sin]; ts = Any[Tuple{Int}, Tuple{Int32}]     # values the caller does not know
    rt(f, t) = Base.Compiler.return_type(f, t)
    rt(+, Tuple{Int, Int})                                        # compile the caller first
    t1 = @elapsed rt(fs[1], ts[1])
    t2 = @elapsed rt(fs[2], ts[2])
    println("return_type at run time: first ", round(1e3t1; digits = 2), " ms, second ", round(1e3t2; digits = 3), " ms")
else
    t1 = @elapsed Base.infer_return_type(sin, (Float64,))
    t2 = @elapsed Base.infer_return_type(cos, (Float32,))
    println("infer_return_type: first ", round(1e3t1; digits = 2), " ms, second ", round(1e3t2; digits = 3), " ms")
end
