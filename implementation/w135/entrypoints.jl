# E-361: julia --project=<env> entrypoints.jl apps/<app>.jl -- the entry points `verify_main` gives for an app, and its sites.
include(abspath(popfirst!(ARGS)))   # run as: julia -e 'include("entrypoints.jl")' apps/<app>.jl
r = TraitWorld.verify_main(main, (Vector{String},))
println(length(r.targets), " targets, ", length(r.entrypoints), " entry points, ", length(r.holes), " run-time sites, complete ", r.complete)
foreach(x -> println("  entry point: ", x), r.entrypoints)
foreach(h -> println("  site: ", h.kind, " ", h.file, ":", h.line, " ", h.call, " | ", last(h.cause)), r.holes)
