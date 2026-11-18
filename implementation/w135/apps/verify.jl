# E-361: with VERIFY=1 the app runs `verify_main` at build time, and registers its entry points (the
# targets no call in the code names; traits §16); with VERIFY=0 the app is built as written.
if get(ENV, "VERIFY", "0") == "1"
    let t0 = time(), r = TraitWorld.verify_main(main, (Vector{String},); entrypoints = true)
        println(Core.stdout, "verify_main: ", length(r.targets), " targets, ", length(r.entrypoints), " entry points, ",
                length(r.holes), " run-time sites, complete ", r.complete, ", ", round(time() - t0; digits = 1), " s")
        TraitWorld.add_entrypoints(r)
        for h in Iterators.take(r.holes, 60)
            println(Core.stdout, "  site: ", h.kind, " ", h.file, ":", h.line, " ", h.call, " | ", last(h.cause))
        end
    end
end
