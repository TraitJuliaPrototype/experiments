# A compile workload with the dispatch profiler on: functions new to the session, compiled from
# their first calls. Run by check.sh in both images.
ccall(:jl_facts_dispatch_profile_reset, Cvoid, ())
module W
f1(x) = sum(abs2, x) / length(x)
f2(d::Dict) = sort!(collect(keys(d)); by = string)
f3(v) = [string(i, ":", x) for (i, x) in enumerate(v)]
f4(a, b) = Base.mapreduce((x, y) -> x * y, +, a, b)
struct P{T}; x::T; y::T; end
Base.:+(p::P, q::P) = P(p.x + q.x, p.y + q.y)
f5(ps) = reduce(+, ps)
end
t = @elapsed begin
    W.f1(rand(10)); W.f2(Dict(:a => 1, :b => 2)); W.f3([1.5, 2.5]); W.f4([1, 2], [3, 4])
    W.f5([W.P(1, 2), W.P(3, 4)]); W.f5([W.P(1.0, 2.0)])
end
println("compile work ", round(1000t, digits = 1), " ms")
