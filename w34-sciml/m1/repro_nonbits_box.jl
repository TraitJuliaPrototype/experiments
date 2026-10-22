# E-157, a minimal reproducer: a `Dynamic{Callable}` call boxes an argument that is an immutable
# non-bits value (a named tuple holding a vector): one allocation per call. A bits named tuple and
# a Vector are not boxed. (TraitWorld/src/core.jl:1118 `_ctype`, :1146 the `ccall`.)
using TraitWorld
f(a, p) = (a[1] = p[1][1]; nothing)
const NB = @NamedTuple{c::Vector{Float64}}
const B = @NamedTuple{c::Float64}
g(a, p) = (a[1] = p.c; nothing)
loop(h, a, p, n) = (for _ in 1:n; h(a, p); end; nothing)
function perc(h, a, p)
    loop(h, a, p, 10)
    g0 = Base.gc_num(); loop(h, a, p, 10^6); d = Base.GC_Diff(Base.gc_num(), g0)
    return d.allocd / 10^6, Base.gc_alloc_count(d) / 10^6
end
a = zeros(1)
hn = Dynamic{Callable{Tuple{Vector{Float64},NB},Nothing}}(f)
hb = Dynamic{Callable{Tuple{Vector{Float64},B},Nothing}}(g)
hv = Dynamic{Callable{Tuple{Vector{Float64},Vector{Float64}},Nothing}}((a, p) -> (a[1] = p[1]; nothing))
println("non-bits named tuple: bytes, allocations per call = ", perc(hn, a, (c = [1.0],)))
println("bits named tuple:     bytes, allocations per call = ", perc(hb, a, (c = 1.0,)))
println("Vector:               bytes, allocations per call = ", perc(hv, a, [1.0]))
println("load: ", join(first(split(read("/proc/loadavg", String)), 3), " "))
