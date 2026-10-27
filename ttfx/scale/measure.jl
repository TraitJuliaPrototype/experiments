# E-171: one fresh session per call: julia --project=env measure.jl <S|M|L>
# Prints the load, a first call at a cached key, and a new type implemented in the session with its first call.
X = ARGS[1]; pkg = Symbol("Scale", X)
Base.cumulative_compile_timing(true)
c() = Base.cumulative_compile_time_ns()[1] / 1e9
t0 = time(); c0 = c()
@eval using $pkg
println("load ", round(time() - t0; digits = 3), " s (compile ", round(c() - c0; digits = 3), ")")
C = getfield(getfield(Main, pkg), :Core_)
t0 = time(); c0 = c()
r = Base.invokelatest(C.f1, C.T1(1.0, [1.0, 2.0]), 2)
println("cached key, first call ", round(time() - t0; digits = 3), " s (compile ", round(c() - c0; digits = 3), ")")
t0 = time(); c0 = c()
@eval Main struct TNew; v::Float64; w::Vector{Float64}; end
@eval Main begin
    $(C).@implement $(C).Tr1 TNew begin
        a1(x) = x.v; b1(x, y) = x.v * y; c1(x) = x.w
    end
end
println("new type, implement ", round(time() - t0; digits = 3), " s (compile ", round(c() - c0; digits = 3), ")")
t0 = time(); c0 = c()
r = Base.invokelatest(C.f1, Main.TNew(1.0, [1.0, 2.0]), 2)
println("new type, first call ", round(time() - t0; digits = 3), " s (compile ", round(c() - c0; digits = 3), ")")
println("strict ", get(ENV, "JULIA_TW_STRICT", "0"))
