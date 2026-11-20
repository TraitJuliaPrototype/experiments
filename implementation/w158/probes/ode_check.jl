# W-158 (E-510): the ODE program's `main` (../w135/apps/ode.jl), the build's check run in the session.
# `PATCH=1` lays the worktree's compiler change over the session's (`cc_patch`) first.
if get(ENV, "PATCH", "0") == "1"
    include(joinpath(@__DIR__, "..", "..", "w156", "tools", "cc_patch.jl"))
    cc_patch(joinpath(@__DIR__, "..", "..", "..", "..", "wt", "w158-julia", "Compiler", "src", "abstractinterpretation.jl"),
             [:closed_choice_bits, :abstract_call_gf_by_type])
end
include(joinpath(@__DIR__, "..", "..", "w135", "apps", "ode.jl"))
r = TraitWorld.verify_main(main, (Vector{String},))
println("verify_main: ", length(r.targets), " targets, ", length(r.holes), " holes, complete ", r.complete)
for h in r.holes
    println("  site: ", h.kind, " ", h.file, ":", h.line, " ", h.call, " | ", last(h.cause))
end
main(String[])
