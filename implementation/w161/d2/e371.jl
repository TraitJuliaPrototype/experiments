# W-161, E-501: E-371's control on the head. A loop of 10^7 calls of an argument declared Callable{Tuple{Float64},
# Float64}: the function boxed (the default), the wrapper (`compiled_for(f)`), and the same loop over a plain argument.
# The minimum of 5 runs, ns a call. Under D-2 the signature is checked once, where the function is boxed or the
# wrapper enters; each call of the box asserts the result.
#     julia --project=<TraitWorld tree> e371.jl
using TraitWorld
const C = Core.Callable
const HEAD = isdefined(TraitWorld, :ByType)   # the baseline (julia-unified, TraitWorld-base): `compiled_for(f)` written
                                              # at the call it decides, the box by `with_dynamic(f)`
f(x::Float64) = x * 1.0000001
function viacallable(g::C{Tuple{Float64}, Float64}, x::Float64, n::Int)
    for _ in 1:n; x = g(x); end
    return x
end
function plain(g, x::Float64, n::Int)
    for _ in 1:n; x = g(x); end
    return x
end
const SINK = Ref(0.0)
@noinline plainf(x, n) = plain(f, x, n)
@static if HEAD
    const cf = TraitWorld.ByType.compiled_for
    @noinline compiledf(x, n) = viacallable(cf(f), x, n)
    @noinline boxedf(x, n) = viacallable(f, x, n)
    # the entry's cost: one call of the method with a fresh argument each time, n = 1
    @noinline entry_boxed(x, n) = (s = 0.0; for _ in 1:n; s += viacallable(f, x, 1); end; s)
    @noinline entry_compiled(x, n) = (s = 0.0; for _ in 1:n; s += viacallable(cf(f), x, 1); end; s)
else
    @noinline compiledf(x, n) = viacallable(compiled_for(f), x, n)
    @noinline boxedf(x, n) = viacallable(with_dynamic(f), x, n)
    @noinline entry_boxed(x, n) = (s = 0.0; for _ in 1:n; s += viacallable(with_dynamic(f), x, 1); end; s)
    @noinline entry_compiled(x, n) = (s = 0.0; for _ in 1:n; s += viacallable(compiled_for(f), x, 1); end; s)
end
ns(h, n) = minimum(@elapsed(SINK[] += h(1.0, n)) for _ in 1:5) / n * 1e9
n = 10^7
plainf(1.0, 10); compiledf(1.0, 10); boxedf(1.0, 10); entry_boxed(1.0, 10); entry_compiled(1.0, 10)
println("plain argument:                  ", round(ns(plainf, n); digits = 2), " ns")
println("Callable, compiled_for(f):       ", round(ns(compiledf, n); digits = 2), " ns")
println("Callable, boxed (the default):   ", round(ns(boxedf, n); digits = 2), " ns")
println("one entry, boxed (n = 1):        ", round(ns(entry_boxed, 10^6); digits = 2), " ns")
println("one entry, compiled_for (n = 1): ", round(ns(entry_compiled, 10^6); digits = 2), " ns")
@assert compiledf(1.0, 3) == plainf(1.0, 3) == boxedf(1.0, 3)
