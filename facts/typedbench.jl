# Typed and untyped trait calls (total(t, 16)) against the plain loop; from session 24. Run: julia --project=<env with TraitWorld> typedbench.jl
include(joinpath(@__DIR__, "typedbench_defs.jl"))
struct Ramp; base::Vector{Float64}; n::Int; end
Columns.ncols(r::Ramp) = r.n
Columns.col(r::Ramp, i::Int) = r.base .* i
@implement ColTable Ramp
f(x) = total(x, 16)
function bench(x, n)
    s = 0.0
    for _ in 1:n; s += f(x); end
    s
end
gany(xs::Vector{Any}) = total(xs[1], 16)
function benchany(xs, n)
    s = 0.0
    for _ in 1:n; s += gany(xs); end
    s
end
plain(v) = (s = 0.0; for i in 1:length(v), j in 1:16; s += v[i][j]; end; s)
function benchp(v, n); s = 0.0; for _ in 1:n; s += plain(v); end; s; end
v16 = [rand(16) for _ in 1:4]
for (name, x) in (("Vector", v16), ("Meas (immutable, fwd)", Meas("a", v16)), ("MeasM (mutable, fwd)", MeasM("b", v16)))
    bench(x, 10); a = @allocated bench(x, 1000)
    t = minimum(@elapsed(bench(x, 10^5)) for _ in 1:5) / 10^5 * 1e9
    xs = Any[x]; benchany(xs, 10); ta = minimum(@elapsed(benchany(xs, 10^5)) for _ in 1:5) / 10^5 * 1e9
    println(rpad(name, 24), " typed ", round(t, digits = 1), " ns (", a, " bytes/1000 calls), untyped ", round(ta, digits = 1), " ns")
end
benchp(v16, 10); tp = minimum(@elapsed(benchp(v16, 10^5)) for _ in 1:5) / 10^5 * 1e9
println(rpad("plain loop", 24), " ", round(tp, digits = 1), " ns")
# the same loop as the worker: `len` an argument of a function not inlined into the caller
@noinline plainlen(v, len) = (s = 0.0; for i in 1:length(v), j in 1:len; s += v[i][j]; end; s)
function benchpl(v, n); s = 0.0; for _ in 1:n; s += plainlen(v, 16); end; s; end
benchpl(v16, 10); tpl = minimum(@elapsed(benchpl(v16, 10^5)) for _ in 1:5) / 10^5 * 1e9
println(rpad("plain, len an argument", 24), " ", round(tpl, digits = 1), " ns")
