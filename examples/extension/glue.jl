# A glue extension that declares conformances (the review's example 7, second half; design.md
# §3.2 "conformances are the sanctioned extension point"; lesson 2.2, the (key owner, function
# owner) pair no package owns). GShapes (a trait package) has an extension on GGeom (plain types)
# that declares `Shape` for GGeom's `Circle` and `Square`, with a workload.
#
#     julia --project=../env glue.jl [shapes-first | geom-first]
#
# Expected:
#   - loading GGeom after GShapes activates the extension and invalidates none of GShapes' code
#     (a conformance applies at no existing fact), unlike S9's extension, which adds a method at one;
#   - the conformances work, values identical to plain Julia;
#   - the extension's image holds code for the pair (its workload ran at precompile time), so the
#     first call compiles nothing new for it — checked by reflection; the timing after (B).
include(joinpath(@__DIR__, "..", "common.jl"))
using TraitWorld: Dynamic
order = isempty(ARGS) ? "shapes-first" : ARGS[1]
println("julia ", VERSION, "  facts mode (all): ", facts_mode(), "  order: ", order)
if order == "shapes-first"
    @eval using GShapes
    check("GShapes alone: twice(Unit) = 2.0", GShapes.twice(GShapes.ShapeCore.Unit()) == 2.0)
    cis = valid_cis(GShapes)
    @eval using GGeom
    n = nlost(cis)
    check("loading GGeom (the extension's trigger) invalidates none of GShapes' code", n == 0, "$n of $(length(cis)) lost")
else
    @eval using GGeom
    @eval using GShapes
end
ext = Base.get_extension(GShapes, :GShapesGGeomExt)
check("the glue extension is active", ext !== nothing)
# code for the pair present before its first call in this session (from the extension's image)
paircis = filter(ci -> _within(_cimodule(ci), GShapes) && (mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def;
                 occursin("Circle", string(mi.specTypes))), allcis())
if isempty(paircis)
    pending("the extension's image holds GShapes' workers for GGeom's types", "part (B): images keep native code for the facts owner",
            "no CodeInstance of GShapes mentions Circle before the first call")
else
    check("the extension's image holds GShapes' code for GGeom's types", true, "$(length(paircis)) CodeInstances before the first call")
end
c, s = GGeom.Circle(1.0), GGeom.Square(2.0)
check("twice(Circle(1.0)) = 2π", Base.invokelatest(GShapes.twice, c) == 2pi)
check("twice(Square(2.0)) = 8.0", Base.invokelatest(GShapes.twice, s) == 8.0)
mixed = Base.invokelatest(() -> Dynamic{GShapes.Shape}[Dynamic{GShapes.Shape}(c), Dynamic{GShapes.Shape}(s), Dynamic{GShapes.Shape}(GShapes.ShapeCore.Unit())])
check("areasum over GGeom's and GShapes' types = plain sum", Base.invokelatest(GShapes.areasum, mixed) == pi + 4.0 + 1.0)
# To measure after (B): first call of twice(Circle) in a fresh session, against a session in which
# the extension has no workload (expected: nothing compiled with the workload).
summary()
