# E7, product setting: does trait code pay the Vector{Any} tails? A trait module whose functions call
# Base's filter! on a Vector{Any}, against the same code in Main (plain). Then a Callable predicate
# over a Vector{Any}: the pointer call at the declared signature against the run-time site.
using BenchmarkTools, Random
using TraitWorld
println("julia ", VERSION, "  facts default (all): ", Base.Compiler.NativeInterpreter().facts)
Random.seed!(1)
const N = 1000
const anys = shuffle!([rand(1:N, N); [randstring(rand(1:30)) for _ in 1:N]])[1:N]::Vector{Any}

@trait_module module TM
using TraitWorld
export tfilt!, tcount, tcount_cb, tdictloop
tfilt!(v::Vector{Any}) = filter!(x -> isa(x, Int), v)                       # Base's filter!, reached from trait code
tcount(v::Vector{Any}) = (n = 0; for x in v; n += isa(x, Int); end; n)      # no call on the element: a builtin
tcount_cb(f::Callable{Tuple{Any}, Bool}, v::Vector{Any}) = (n = 0; for x in v; n += f(x); end; n)
tdictloop(d::Dict{String,Any}) = (n = 0; for (k, v) in d; n += v isa Int; end; n)
end
using .TM
pfilt!(v::Vector{Any}) = filter!(x -> isa(x, Int), v)
pcount_cb(f, v::Vector{Any}) = (n = 0; for x in v; n += f(x)::Bool; end; n)
pdictloop(d::Dict{String,Any}) = (n = 0; for (k, v) in d; n += v isa Int; end; n)
d = copy(anys)
println("trait module  filter!(pred, ::Vector{Any})   ", round(1e9 * (@belapsed tfilt!(d) setup=(d=copy($anys)) evals=1) / N; digits = 1), " ns/elt")
println("plain         filter!(pred, ::Vector{Any})   ", round(1e9 * (@belapsed pfilt!(d) setup=(d=copy($anys)) evals=1) / N; digits = 1), " ns/elt")
println("trait module  isa on each element            ", round(1e9 * @belapsed(tcount($anys)) / N; digits = 1), " ns/elt")
try
    f = x -> isa(x, Int)
    tcount_cb(f, anys)
    println("trait module  Callable{Tuple{Any},Bool} pred  ", round(1e9 * @belapsed(tcount_cb($f, $anys)) / N; digits = 1), " ns/elt  ", @allocated(tcount_cb(f, anys)) / N, " B/elt")
    println("plain         the same closure, dynamic     ", round(1e9 * @belapsed(pcount_cb($f, $anys)) / N; digits = 1), " ns/elt")
catch e
    println("Callable case failed: ", sprint(showerror, e)[1:min(end, 300)])
end
dd = Dict{String,Any}(string(i) => (isodd(i) ? i : string(i)) for i in 1:N)
println("trait module  for (k, v) in Dict{String,Any}  ", round(1e9 * @belapsed(tdictloop($dd)) / N; digits = 1), " ns/elt  ", @allocated(tdictloop(dd)) / N, " B/elt")
println("plain         for (k, v) in Dict{String,Any}  ", round(1e9 * @belapsed(pdictloop($dd)) / N; digits = 1), " ns/elt  ", @allocated(pdictloop(dd)) / N, " B/elt")
