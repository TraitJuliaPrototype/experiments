# W-168 (open issue 256, proposal (b)): what the check of a program costs in a session. The program is loaded
# as the session of `w120/session_marks.jl` loads it (VERIFY=0), then ONE check is timed twice in the same
# process: `verify` (TraitWorld.verify_main) or `fully` (TraitWorld.fully_typed) at `main` for (Vector{String},).
# Then, once, the walk and the build's own check apart (the library's internals) and what the check did: the
# signatures the walk inferred, the targets, the sites.
#     julia --project=<env> check_cost.jl <verify|fully> <app.jl> [app args]
# Prints `first` and `second` (wall ms, compile ms, result size) and a line `split`.
mode = popfirst!(ARGS); app = abspath(popfirst!(ARGS))
include(app)
const TW = TraitWorld
const CC = Base.Compiler
ms(x) = round(x / 1e6; digits = 1)
function timed(f)
    Base.cumulative_compile_timing(true)
    c0 = Base.cumulative_compile_time_ns()[1]; t0 = time_ns()
    r = f()
    t1 = time_ns(); c1 = Base.cumulative_compile_time_ns()[1]
    Base.cumulative_compile_timing(false)
    return r, ms(t1 - t0), ms(c1 - c0)
end
check() = mode == "verify" ? TW.verify_main(Main.main, (Vector{String},); entrypoints = true) :
                             TW.fully_typed(Main.main, (Vector{String},))
size_of(r) = mode == "verify" ? "targets $(length(r.targets)), entry points $(length(r.entrypoints)), sites $(length(r.holes)), complete $(r.complete)" :
                                "sites $(length(r.sites)), complete $(r.complete), fully typed $(TW.isfullytyped(r))"
for tag in ("first", "second")
    r, w, c = Base.invokelatest(timed, check)
    println(tag, " ", mode, ": wall ", w, " ms, compiling ", c, " ms | ", size_of(r))
end
# the parts, a third time each (everything compiled): the walk, then the build's own check
sig = Base.signature_type(Main.main, (Vector{String},))
world = Base.get_world_counter()
w, tw, _ = Base.invokelatest(timed, () -> TW._walk(sig, world; bound = mode == "verify" ? TW._VERIFY_BOUND : TW._WALK_BOUND))
s, ts, _ = Base.invokelatest(timed, () -> TW._build_sites(sig, world, w.sites))
println("split: walk ", tw, " ms (", length(w.seen), " signatures inferred, ", length(w.sites), " sites of its own), build's check ", ts,
        " ms (", s === nothing ? "no single method" : string(length(s), " sites"), ")")
