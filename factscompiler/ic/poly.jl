# Experiment 3: a run-time site that sees many types. `out[i] = x` on a `Vector{Any}` calls
# `setindex!(::Array{Any}, @nospecialize(x), ::Int)` (not inlined under the facts mode), with
# values of 1, 4 and 16 types; and `push!` the same way.
#     julia [-J facts/sys.so] --project=<env with BenchmarkTools> poly.jl
using BenchmarkTools
struct T1; a::Int; end; struct T2; a::Int; end; struct T3; a::Int; end; struct T4; a::Int; end
const KINDS = Any[T1(1), T2(1), T3(1), T4(1), 1, 1.0, 0x01, Int32(1), "a", :a, 'a', 1//2, [1], (1,), nothing, true]
const N = 1000
vals(k) = Any[KINDS[mod1(i, k)] for i in 1:N]
fill_any!(out, v) = (for i in eachindex(v); out[i] = v[i]; end; out)
push_any(v) = (out = Any[]; for x in v; push!(out, x); end; out)
mode = Base.Compiler.NativeInterpreter().facts ? "all  " : "plain"
for k in (1, 4, 16)
    v = vals(k); out = Vector{Any}(undef, N)
    fill_any!(out, v); push_any(v)
    t1 = @belapsed fill_any!($out, $v); t2 = @belapsed push_any($v)
    println(mode, "  ", lpad(k, 2), " types   setindex! ", lpad(round(1e9 * t1 / N; digits = 1), 6), " ns   push! ", lpad(round(1e9 * t2 / N; digits = 1), 6), " ns")
end
