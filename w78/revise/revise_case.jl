# W-78: Revise's edit of a bounded function in a trait module's file (traits §2)
using Revise, TraitWorld
dir = @__DIR__
cp(joinpath(dir, "RevT.orig.jl"), joinpath(dir, "RevT.jl"); force = true)
includet(joinpath(dir, "RevT.jl"))
using .RevT
println("R first: ", rsq([1.0, 2.0]))
src = read(joinpath(dir, "RevT.jl"), String)
sleep(1.1)
write(joinpath(dir, "RevT.jl"), replace(src, "rsq(v::RVals) = (s = 0.0; for x in rvals(v); s += abs2(x); end; s)" => "rsq(v::RVals) = 2 * sum(rvals(v))"))
Revise.revise()
println("R after Revise: ", Base.invokelatest(rsq, [1.0, 2.0]), "  (6.0 expected)")
println("R methods: ", length(methods(rsq)))
for m in methods(rsq); println("R   ", m); end
cp(joinpath(dir, "RevT.orig.jl"), joinpath(dir, "RevT.jl"); force = true)
