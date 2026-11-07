# E-275: steady-state dynamic calls of `length` over 50 containers held as `Any`, ns per call (one
# process, 400,000 rounds). Run per tree, alternating trees:
#     <tree>/julia --startup-file=no experiments/unification/stack/e275_dyn.jl
cs = Any[]
for T in (Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64, Float32, Float64, Char, Bool, String, Symbol, Any, Int128, UInt128, Float16, ComplexF64, Rational{Int}, Missing, Nothing, BigInt, Vector{Int}, Tuple{Int})
    push!(cs, T[]); push!(cs, (one(Int8), 1))
end
cs = cs[1:50]
function loop(cs, n)
    s = 0
    for _ in 1:n, c in cs
        s += length(c)
    end
    s
end
loop(cs, 10)
t = @elapsed loop(cs, 400_000)
println(round(t / (400_000 * 50) * 1e9; digits = 1), " ns per call")
