# W-19, P14: a dynamic call to a method whose cache entry has `Any` positions, at one call site that
# sees 1, 4 or 16 value types. The container is read through a `Ref{Any}`, so each store is a
# dynamic call of `setindex!(::Vector{Any}, x, ::Int)`.
#   julia --startup-file=no dispatch_site.jl
struct T1; a::Int; end; struct T2; a::Int; end; struct T3; a::Int; end; struct T4; a::Int; end
const KINDS = Any[T1(1), T2(1), T3(1), T4(1), 1, 1.0, 0x01, Int32(1), "a", :a, 'a', 1//2, [1], (1,), nothing, true]
const N = 1000
vals(k) = Any[KINDS[mod1(i, k)] for i in 1:N]
function fill_dyn!(r::Base.RefValue{Any}, v::Vector{Any})
    out = r[]
    for i in eachindex(v)
        out[i] = v[i]
    end
    return nothing
end
function push_dyn!(r::Base.RefValue{Any}, v::Vector{Any})
    out = r[]
    for x in v
        push!(out, x)
    end
    empty!(out)
    return nothing
end
best(f, args...) = minimum((t = time_ns(); for _ in 1:200; f(args...); end; (time_ns() - t) / 200) for _ in 1:15)
for k in (1, 4, 16)
    v = vals(k); r = Ref{Any}(Vector{Any}(undef, N)); p = Ref{Any}(Any[])
    fill_dyn!(r, v); push_dyn!(p, v)
    t1 = best(fill_dyn!, r, v) / N; t2 = best(push_dyn!, p, v) / N
    println(lpad(k, 2), " types   setindex! ", lpad(round(t1; digits = 1), 6), " ns   push! ", lpad(round(t2; digits = 1), 6), " ns")
end
