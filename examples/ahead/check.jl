# Step 4: code compiled ahead from a declared implementation. A fresh session loads AheadP, which
# declares `Shape{Hexagon}` and calls nothing: the worker of GShapes' `twice` for Hexagon's key,
# and the entry's method for untyped calls, must come with AheadP's image, compiled.
#     julia --project=ahead/env ahead/check.jl
include(joinpath(@__DIR__, "..", "common.jl"))
using TraitWorld, GShapes, AheadP
twice = GShapes.ShapeCore.twice
has_code(mi) = isdefined(mi, :cache) && (ci = mi.cache; ci.max_world == typemax(UInt) && (ci.inferred !== nothing || ci.invoke != C_NULL))
ws = [mi for m in methods(twice) if TraitWorld._isworker(m) for mi in Base.specializations(m) if mi isa Core.MethodInstance]
hexw = [mi for mi in ws if occursin("Hexagon", string(mi.specTypes))]
check("the worker for Hexagon's key comes with AheadP's image", !isempty(hexw) && all(has_code, hexw), string([mi.specTypes for mi in ws]))
cs = [mi for (g, n, tag, tpos) in GShapes.ShapeCore.__tw_untyped__ if g === twice for m in methods(tag) for mi in Base.specializations(m) if mi isa Core.MethodInstance]
check("the entry's method for untyped calls comes with it", any(mi -> occursin("Hexagon", string(mi.specTypes)) && has_code(mi), cs), string([mi.specTypes for mi in cs]))
x = Any[AheadP.Hexagon(1.0)][1]
t = @elapsed v = twice(x)
check("an untyped call gives the typed result", v == twice(AheadP.Hexagon(1.0)), "untyped $v")
println("first untyped call: ", round(1000t; digits = 2), " ms")
summary()
