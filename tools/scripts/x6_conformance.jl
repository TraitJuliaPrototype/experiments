# W-85 (a check of a callpath reading): E-218's IntA has no HasDu; what a negative implementation lookup costs.
#     julia --project=<TraitWorld> experiments/tools/scripts/x6_conformance.jl
include(joinpath(@__DIR__, "..", "..", "w80", "x6.jl"))
using TraitWorld
const TW = TraitWorld
p = TW.EntryPos{typeof(cb),1,1}()
f1(o, n) = (for _ in 1:n; Base.donotdelete(TW.conformance(TW.As{HasDu}(), Base.inferencebarrier(o))); end)
f2(o, n) = (for _ in 1:n; Base.donotdelete(TW._assemble(TW.needed(p), Base.inferencebarrier(o))); end)
for (nm, f) in (("conformance(As{HasDu}, x)", f1), ("_assemble(needed(cb), x)", f2)), o in (a, b)
    f(o, 10)
    t = minimum(@elapsed(f(o, 10^5)) for _ in 1:3) / 1e5
    by = @allocated(f(o, 10^5)) / 1e5
    println(rpad(nm, 28), rpad(typeof(o), 6), round(t * 1e9; digits = 1), " ns ", by, " bytes")
end
