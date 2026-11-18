# E-353: the cost of strict mode's inference of an image's memberships at load.
# Run: JULIA_TW_STRICT=1 julia --startup-file=no --project=<env> e353_load_cost.jl <packages...>
# The first call ran inside the load; here the same work is timed again from the first entry
# (inference cached) and in a count of the checked calls it infers.
# With E353_SKIP=1 the report is skipped during the load (the cursor is set past every entry), so the
# timed call is the first one: its time is what the load pays.
import TraitWorld
skip = get(ENV, "E353_SKIP", "0") == "1"
skip && (TraitWorld._STRICT_ENTRY_CURSOR[] = typemax(Int) >> 1)
t_load = @elapsed for p in ARGS; Base.require(Main, Symbol(p)); end
n = Int(ccall(:jl_activated_memberships_count, Csize_t, ()))
recs = sum(length, values(TraitWorld._CHECKED_RESULTS); init = 0)
TraitWorld._STRICT_ENTRY_CURSOR[] = 0
t = @elapsed TraitWorld._report_load_memberships!()
println("e353_load_cost: packages $(join(ARGS, ", ")); load $(round(t_load, digits = 3)) s; activated entries $n; ",
        "checked results $recs; the report $(skip ? "for the first time" : "again") over all $(round(t * 1e3, digits = 2)) ms; findings $(length(TraitWorld._LOAD_MEMBERSHIPS))")
