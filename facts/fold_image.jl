order = ARGS[1]
order == "before" && @eval Base.clamp(x::Int, lo::Int, hi::Int) = 1.5      # wins at the concrete signature
using FoldPkg
order == "after" && @eval Base.clamp(x::Int, lo::Int, hi::Int) = 1.5
plain_map(n) = map(x -> clamp(x, 0, n), Int[])
plain_sum(n) = clamp(n, 0, 10) + 0
println(rpad(order, 7), "trait: ", (eltype(emptymap(3)), clampsum(3)), "  plain: ", (eltype(plain_map(3)), plain_sum(3)))
