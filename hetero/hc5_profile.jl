# E5: the dispatch profiler on filter! over a Vector{Any} (run with JULIA_FACTS_DISPATCH_PROFILE=1):
# which callees are dispatched at run time, and how many times per element.
using Random
Random.seed!(1)
const N = 1000
const ints = rand(1:N, N)
const strings = [randstring(rand(1:30)) for _ in 1:N]
const anys = shuffle!([ints; strings])[1:N]::Vector{Any}
pred = x -> isa(x, Int)
filter!(pred, copy(anys))         # compile
ccall(:jl_facts_dispatch_profile_reset, Cvoid, ())
for _ in 1:100
    filter!(pred, copy(anys))
end
println("100 x filter! over ", N, " elements = ", 100N, " element visits")
