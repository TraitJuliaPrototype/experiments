# Step 4: code compiled ahead from a declared implementation. A fresh session loads AheadP, which
# declares `Shape{Hexagon}` and calls nothing: the worker of GShapes' `twice` for Hexagon's key,
# and the entry's method for `compiled_for` from untyped callers (the table), must come with AheadP's
# image, compiled; no entry method per type is defined.
#     julia --project=ahead/env ahead/check.jl
include(joinpath(@__DIR__, "..", "common.jl"))
using TraitWorld, GShapes, AheadP
twice = GShapes.ShapeCore.twice
has_code(mi) = isdefined(mi, :cache) && (ci = mi.cache; ci.max_world == typemax(UInt) && (ci.inferred !== nothing || ci.invoke != C_NULL))
ws = [mi for m in methods(twice) if TraitWorld._isworker(m) for mi in Base.specializations(m) if mi isa Core.MethodInstance]
hexw = [mi for mi in ws if occursin("Hexagon", string(mi.specTypes))]
check("the worker for Hexagon's key comes with AheadP's image", !isempty(hexw) && all(has_code, hexw), string([mi.specTypes for mi in ws]))
cs = [mi for (g, n, tag, tpos) in GShapes.ShapeCore.__tw_untyped__ if g === twice for m in methods(tag) for mi in Base.specializations(m) if mi isa Core.MethodInstance]
check("the entry's method for compiled_for from untyped callers comes with it", any(mi -> occursin("Hexagon", string(mi.specTypes)) && has_code(mi), cs), string([mi.specTypes for mi in cs]))
em = [m for m in methods(twice) if m.module === AheadP]
# no entry method per type is compiled ahead: reached by a dispatch at run time, it would make an
# untyped caller `Compiled` (traits §15; lowering §15.1)
check("no entry method for Hexagon is defined: an untyped caller stays Dynamic", isempty(em), string(em))
x = Any[AheadP.Hexagon(1.0)][1]
t = @elapsed v = twice(x)
check("an untyped call gives the typed result", v == twice(AheadP.Hexagon(1.0)), "untyped $v")
println("first untyped call: ", round(1000t; digits = 2), " ms")
# rough: untyped calls (Dynamic) of a type declared in an image and of one declared in the session
toplevel(:(struct Tri; s::Float64; end; @implement Shape{Tri} begin area(t) = 0.4330127018922193 * t.s^2 end))
const XH = Any[AheadP.Hexagon(1.0) for _ in 1:1000]; const XT = Any[Base.invokelatest(getglobal(Main, :Tri), 1.0) for _ in 1:1000]
loopc(v) = (s = 0.0; for y in v; s += twice(y)::Float64; end; s)
loopc(XH); Base.invokelatest(loopc, XT)
th = minimum(@elapsed(loopc(XH)) for _ in 1:200); tt = minimum(@elapsed(Base.invokelatest(loopc, XT)) for _ in 1:200)
println("untyped call, a type compiled ahead: ", round(1e6th; digits = 1), " ns; a type declared in the session: ", round(1e6tt; digits = 1), " ns")
summary()
