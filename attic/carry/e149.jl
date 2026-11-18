# E-149 (W-18): what keeping values as `Kept{X}` costs against `Dynamic{X}`.
# One session, product setting, a few minutes: minimum of 20 timed runs per row, after warm-up.
#     julia --project=../../TraitWorld e149.jl
using TraitWorld
Core.eval(Main, Expr(:toplevel, :(@trait_module module E149
using TraitWorld
export Shape, area, total
@trait Shape begin
    area(s::Shape)::Float64
end
total(xs::Iterable{Shape}) = (a = 0.0; for x in xs; a += area(x); end; a)
end)))
using .E149
for (i, T) in enumerate((:S1, :S2, :S3, :S4, :S5, :S6, :S7, :S8))
    @eval struct $T; a::Float64; end
    @eval E149.area(s::$T) = s.a * $i
    @eval @implement E149.Shape $T
end
const TYPES = (S1, S2, S3, S4, S5, S6, S7, S8)
const N = 10_000
objs(k) = Any[TYPES[mod1(i, k)](1.0) for i in 1:N]

sumk(v) = (a = 0.0; for x in v; a += E149.area(x); end; a)
pushk!(v, xs, ::Type{H}) where {H} = (empty!(v); for x in xs; push!(v, H(x)); end; v)
allocs(f::F, args...) where {F} = (f(args...); b0 = Base.gc_bytes(); f(args...); Base.gc_bytes() - b0)
function best(f::F, args...) where {F}
    f(args...)
    t = Inf
    for _ in 1:20
        t0 = time_ns(); f(args...); t = min(t, (time_ns() - t0) / N)
    end
    return t
end
row(name, ns, bytes) = println(rpad(name, 58), lpad(string(round(ns; digits = 2)), 8), " ns/elt  ", bytes, " bytes")

for k in (4, 8)
    xs = objs(k)
    vd = Dynamic{Shape}[]; vk = Kept{Shape}[]
    row("push! Dynamic{Shape}, $k types", best(pushk!, vd, xs, Dynamic{Shape}), allocs(pushk!, vd, xs, Dynamic{Shape}))
    row("push! Kept{Shape} (Compiled, by Kept(x)), $k types", best(pushk!, vk, xs, Kept{Shape}), allocs(pushk!, vk, xs, Kept{Shape}))
    row("sum of area over Vector{Dynamic{Shape}}, $k types", best(sumk, vd), allocs(sumk, vd))
    row("sum of area over Vector{Kept{Shape}}, $k types", best(sumk, vk), allocs(sumk, vk))
    row("total(::Vector{Any}) through the view (Kept items), $k types", best(total, xs), allocs(total, xs))
    row("total(::Vector{Dynamic{Shape}}) (met as it is), $k types", best(total, vd), allocs(total, vd))
    row("total(::Vector{Kept{Shape}}) (met as it is), $k types", best(total, vk), allocs(total, vk))
end
