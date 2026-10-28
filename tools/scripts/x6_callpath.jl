# W-85: the path of E-218's calls (experiments/w80/x6.jl): a bounded call on `Dynamic{IntegratorView}` values,
# with the method chosen by the object's traits (`cb`) and with one bound (`cbplain`).
#     julia --project=<TraitWorld> experiments/tools/scripts/x6_callpath.jl
include(joinpath(@__DIR__, "..", "..", "w80", "x6.jl"))
using TraitWorld
for f in (cb, cbplain), i in is
    display(TraitWorld.callpath(f, i)); println()
end
display(TraitWorld.callpath(cb, b)); println()        # a plain IntB, from a typed and an untyped caller
# the code compiled by facts for E-218's loop in trait code, and for the worker of the chosen method
display(TraitWorld.factscode(X6.run_cb, (Vector{Dynamic{IntegratorView}}, Int))); println()
display(TraitWorld.factscode(TraitWorld.callpath(cb, is[2]; time = false))); println()
