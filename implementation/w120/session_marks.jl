# W-120: one session of a program, with marks: the load (the program's file, which loads its
# packages), the first run of `main` (with what it compiles), a second run. Prints one line.
#     julia --project=<env> [--trace-compile=<file> --trace-compile-timing] session_marks.jl <app.jl> [args…]
t0 = time_ns()
app = abspath(popfirst!(ARGS))
include(app)
t1 = time_ns()
out = redirect_stdout(devnull) do
    c0 = Base.cumulative_compile_time_ns()
    Base.cumulative_compile_timing(true)
    a = time_ns(); Base.invokelatest(main, ARGS); b = time_ns()
    c1 = Base.cumulative_compile_time_ns()
    Base.cumulative_compile_timing(false)
    d = time_ns(); Base.invokelatest(main, ARGS); e = time_ns()
    (b - a, (c1[1] - c0[1]), (c1[2] - c0[2]), e - d)
end
ms(x) = round(x / 1e6; digits = 1)
println("load ", ms(t1 - t0), " ms | first run ", ms(out[1]), " ms, of it compiling ", ms(out[2]),
        " ms (again after an invalidation ", ms(out[3]), " ms) | second run ", ms(out[4]), " ms")
