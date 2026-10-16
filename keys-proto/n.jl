include(joinpath(@__DIR__, "p.jl"))
@inline totalN(@nospecialize(t), len::Int) = total_w(view(ColTable, t), len)
loopN(x, n, len) = (s = 0.0; for _ in 1:n; s += totalN(x, len); end; s)
loopNA(xs::Vector{Any}, n, len) = (s = 0.0; for _ in 1:n; s += totalN(xs[1], len)::Float64; end; s)
println("@nospecialize @inline entry, len 16 (ns per call):")
n = 2^16
for (name, x) in (("own", [rand(16) for _ in 1:4]), ("forward Meas", Meas("a", [rand(16) for _ in 1:4])), ("forward MMeas", MMeas([rand(16) for _ in 1:4], 1)))
    println("  ", rpad(name, 16), "typed caller ", round(tm(loopN, x, n, 16) / n * 1e9, digits = 1), "   untyped caller ", round(tm(loopNA, Any[x], n, 16) / n * 1e9, digits = 1),
            "   alloc/call untyped ", @allocated(loopNA(Any[x], 100, 16)) / 100)
end
# a fresh type through an untyped caller: only the conformance method compiles per type
@eval struct NewT; tag::Symbol; data::Vector{Vector{Float64}}; end
@eval @inline view(::Type{ColTable}, u::NewT) = TO{ColTable,Vector{Vector{Float64}}}(u.data, nothing, $(Int(fieldoffset(NewT, 2))))
for k in 1:10
    @eval @inline $(Symbol(:gn, k))(@nospecialize(t), len::Int) = total_w(view(ColTable, t), len) + $k
end
xs = Any[NewT(:a, [rand(16) for _ in 1:4])]
t0 = time_ns()
for k in 1:10
    Base.invokelatest(getfield(Main, Symbol(:gn, k)), xs[1], 16)
end
println("a new type, first calls of 10 entries from untyped code: ", round((time_ns() - t0) / 1e6, digits = 2), " ms")
@eval struct NewT2; data::Vector{Vector{Float64}}; z::Int; end
@eval @inline view(::Type{ColTable}, u::NewT2) = TO{ColTable,Vector{Vector{Float64}}}(u.data, nothing, 0)
xs2 = Any[NewT2([rand(16) for _ in 1:4], 1)]
t0 = time_ns()
for k in 1:10
    Base.invokelatest(getfield(Main, Symbol(:gn, k)), xs2[1], 16)
end
println("a second new type, first calls of the same 10 entries: ", round((time_ns() - t0) / 1e6, digits = 2), " ms")
