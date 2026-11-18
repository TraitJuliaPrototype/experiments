# W-78: Revise's edit of a bounded function in a plain module holding a `@trait_module begin … end` block
using Revise, TraitWorld
dir = @__DIR__
f = joinpath(dir, "RevB.jl")
cp(joinpath(dir, "RevB.orig.jl"), f; force = true)
includet(f)
using .RevB
println("R first: ", rsq([1.0, 2.0]), "  (3.0)")
src = read(f, String)
sleep(1.1)
write(f, replace(src, "rsq(v::RVals) = (s = 0.0; for x in rvals(v); s += x; end; s)" => "rsq(v::RVals) = 2 * sum(rvals(v))"))
Revise.revise()
println("R after Revise: ", Base.invokelatest(rsq, [1.0, 2.0]), "  (6.0 expected)")
println("R methods: ", length(methods(rsq)))
rm(f)
