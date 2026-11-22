# E-361: with VERIFY=1 the app runs `verify_main` at build time, and registers its entry points (the
# targets no call in the code names; traits §16); with VERIFY=0 the app is built as written.
#
# The check is a function, called through `invokelatest` (open issue 256): Julia compiles a top-level block
# that holds a loop whole, and inference of a call to `verify_main` at the session's `main` then runs even where
# the branch is not taken (1.35 s in the ODE program's session). A call through `invokelatest` is not inferred
# into its caller, and a function that is defined and not called is not inferred at all.
function _verify_app_main(f)
    t0 = time()
    r = TraitWorld.verify_main(f, (Vector{String},); entrypoints = true)
    println(Core.stdout, "verify_main: ", length(r.targets), " targets, ", length(r.entrypoints), " entry points, ",
            length(r.holes), " run-time sites, complete ", r.complete, ", ", round(time() - t0; digits = 1), " s")
    TraitWorld.add_entrypoints(r)
    for h in Iterators.take(r.holes, 60)
        println(Core.stdout, "  site: ", h.kind, " ", h.file, ":", h.line, " ", h.call, " | ", last(h.cause))
    end
    nothing
end
get(ENV, "VERIFY", "0") == "1" && Base.invokelatest(_verify_app_main, main)
