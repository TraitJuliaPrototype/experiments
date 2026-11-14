# A control for the rule "a call of an argument declared Callable{A, S} checks A and asserts S
# whatever the instance knows" (compiler §7.4): the call in a loop, compiled for the function's type,
# beside the same loop over a plain argument. Minimum of 5 runs of 10^7 calls, in ns a call.
#     julia --project=experiments/unification experiments/unification/w142/callable_assert_control.jl
using Traits
const C = Core.Callable
f(x::Float64) = x * 1.0000001
function viacallable(g::C{Tuple{Float64}, Float64}, x::Float64, n::Int)
    for _ in 1:n; x = g(x); end
    return x
end
function plain(g, x::Float64, n::Int)
    for _ in 1:n; x = g(x); end
    return x
end
compiled(x, n) = viacallable(compiled_for(f), x, n)
dynamic(x, n) = viacallable(with_dynamic(f), x, n)
const SINK = Ref(0.0)
@noinline plainf(x, n) = plain(f, x, n)
@noinline compiledf(x, n) = compiled(x, n)
@noinline dynamicf(x, n) = dynamic(x, n)
ns(h, n) = minimum(@elapsed(SINK[] += h(1.0, n)) for _ in 1:5) / n * 1e9
n = 10^7
compiled(1.0, 10); dynamic(1.0, 10); plain(f, 1.0, 10)
println("plain argument:            ", round(ns(plainf, n); digits = 2), " ns")
println("Callable, compiled_for(f): ", round(ns(compiledf, n); digits = 2), " ns")
println("Callable, with_dynamic(f): ", round(ns(dynamicf, n); digits = 2), " ns")
@assert compiled(1.0, 3) == plain(f, 1.0, 3) == dynamic(1.0, 3)
