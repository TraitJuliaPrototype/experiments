# Cost of a new trait module defined in the session (definition-time machinery, the policy's
# compile of code no image holds), with or without big loads first.
order = ARGS[1]
using TraitDifferentialEquations
order == "loads" && (using CSV, DataFrames, CairoMakie)
using TraitWorld
t0 = time()
@eval @trait_module module UserLib
using TraitWorld
export Tab, nc, colv, cmean
@trait Tab begin
    nc(t::Tab)::Int
    colv(t::Tab, i::Int)::Vector{Float64}
end
@implement Tab Vector{Vector{Float64}} begin
    nc(t) = length(t)
    colv(t, i) = t[i]
end
cmean(t::Tab, i::Int) = (c = colv(t, i); sum(c) / length(c))
end
t1 = time()
v = UserLib.cmean([[1.0, 2.0], [3.0, 4.0]], 2)
t2 = time()
v2 = UserLib.cmean([[1.0, 2.0, 5.0]], 1)
t3 = time()
println(rpad(order, 6), " define ", round((t1 - t0) * 1000, digits = 1), " ms; first call ", round((t2 - t1) * 1000, digits = 1),
        " ms; second call ", round((t3 - t2) * 1e6, digits = 1), " µs")
