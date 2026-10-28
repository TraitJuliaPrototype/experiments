# Is the run-time `return_type` entry compiled in the system image? (compiler §6.3)
C = Base.Compiler
for T in (C.NativeInterpreter, C.PlainRTInterp)
    mi = try Base.method_instance(C._return_type, (T, DataType)) catch; nothing end
    has = false
    if mi !== nothing && isdefined(mi, :cache)
        ci = mi.cache
        while true
            ci.invoke != C_NULL && (has = true)
            isdefined(ci, :next) || break
            ci = ci.next
        end
    end
    println("_return_type(::", nameof(T), ", ::DataType): ", mi === nothing ? "no instance" : has ? "compiled" : "instance without code")
end
t = @elapsed collect(x for x in Int[])
println("first collect of a generator: ", round(t * 1000; digits = 1), " ms")
t = @elapsed collect(x + 1 for x in Float32[])
println("second: ", round(t * 1000; digits = 1), " ms")
