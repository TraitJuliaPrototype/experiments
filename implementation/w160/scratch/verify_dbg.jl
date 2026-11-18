using TraitWorld
applyf(f::Callable{Tuple{Float64}, Float64}, x::Float64) = f(x)
double(x::Float64) = 2x
r = verify_main(() -> applyf(TraitWorld.ByType.compiled_for(double), 1.0), ())
println(Tuple{typeof(double), Float64} in r.targets)
r = verify_main(() -> applyf(double, 1.0), ())
println(Tuple{typeof(double), Float64} in r.targets)
