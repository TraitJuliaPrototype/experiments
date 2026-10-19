# Step 1: the cost of a call through a Callable in DynamicCall mode (an erased pointer), against a
# direct call and a dynamic call, and the call in an older world (G1.20), alternating worlds.
#     julia --project=<env with TraitWorld> callbench.jl
using TraitWorld, BenchmarkTools
f(x::Float64) = x + 1.0
const D = TraitWorld.dynamic_fn(Tuple{Float64}, Float64, f)
const G = Any[f]
function viad(d, n)
    s = 0.0
    for i in 1:n; s += d(Float64(i)); end
    s
end
function direct(n)
    s = 0.0
    for i in 1:n; s += f(Float64(i)); end
    s
end
function dyn(n)
    s = 0.0
    g = G[1]
    for i in 1:n; s += g(Float64(i))::Float64; end
    s
end
const N = 10^6
viad(D, 10); direct(10); dyn(10)
ns(t) = round(1e9 * t / N; digits = 2)
println("DynamicCall pointer   ", ns(@belapsed viad($D, $N)), " ns/call")
println("direct call           ", ns(@belapsed direct($N)), " ns/call")
println("dynamic call (Any)    ", ns(@belapsed dyn($N)), " ns/call")
# worlds: redefine f, then call through the same pointer in the old world and in the latest
w = Base.get_world_counter()
@eval f(x::Float64) = x + 100.0
old() = Base.invoke_in_world(w, viad, D, 1)
new() = viad(D, 1)
println("old world: ", old(), " (expect 2.0), latest: ", Base.invokelatest(new), " (expect 101.0)")
function alternate(k)
    s = 0.0
    for _ in 1:k; s += Base.invoke_in_world(w, viad, D, 100); s += Base.invokelatest(viad, D, 100); end
    s
end
alternate(2)
t = @belapsed alternate(100)
println("alternating worlds, 100 calls each way: ", round(1e9 * t / (100 * 200); digits = 2), " ns/call (incl. invoke_in_world)")
