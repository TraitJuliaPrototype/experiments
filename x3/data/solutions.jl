# E-227, E-228: the workload's solutions (written by gen.jl), as upstream's solution fields `t` and `u` read them.
"The three solutions (lorenz, robertson, vanderpol) as named tuples `(t, u)`, `u` a vector of states."
function readsolutions(path = joinpath(@__DIR__, "solutions.bin"))
    open(path) do io
        map(1:3) do _
            n = read(io, Int64); m = read(io, Int64)
            t = Vector{Float64}(undef, n); read!(io, t)
            u = [(v = Vector{Float64}(undef, m); read!(io, v); v) for _ in 1:n]
            (t = t, u = u)
        end
    end
end
