# E-202 (W-66, the facts-first review §2.4): the first-call checks a session runs, and what collecting the
# images' check records costs. At the load mark: `_note_checked_ahead!` timed again over every loaded package.
# At the end: the checks run in the session, how many of their workers' facts code came from an image, and the
# time to run their rule checks again.
#     julia --project=<env> checks_probe.jl <workload script> <outdir>   (from experiments/ttfx)
const N0 = Ref(0)
const TWID = Base.PkgId(Base.UUID("7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"), "TraitWorld")
function _on_mark(step)
    haskey(Base.loaded_modules, TWID) || return
    TW = Base.loaded_modules[TWID]
    step == "load" && (N0[] = length(getglobal(TW, :_CHECKED_IN_SESSION)))
    if step == "load" && isdefined(TW, :_note_checked_ahead!)
        roots = [m for (id, m) in Base.loaded_modules if id.name != "Main"]
        t = @elapsed foreach(m -> Base.invokelatest(getglobal(TW, :_note_checked_ahead!), m), roots)
        println("K note_checked_ahead over ", length(roots), " packages: ", round(t * 1000; digits = 1), " ms; records ",
                length(getglobal(TW, :_CHECKED_AHEAD)[]))
    elseif step == "again"
        # the list is a constant of TraitWorld's image: the entries before the load mark are its build's
        sigs = getglobal(TW, :_CHECKED_IN_SESSION)[N0[]+1:end]
        inimg = 0
        for sig in sigs
            w = getglobal(TW, :_worker_sig)(sig)
            mi = ccall(:jl_method_lookup_by_tt, Any, (Any, Csize_t, Any), w, Base.get_world_counter(), nothing)
            mi isa Core.MethodInstance && isdefined(mi, :cache) || continue
            ci = mi.cache
            while ci isa Core.CodeInstance
                ci.owner === :facts && ccall(:jl_object_in_image, Cint, (Any,), ci) != 0 && (inimg += 1; break)
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
        wp = getglobal(TW, :worker_problems)
        t = @elapsed foreach(s -> Base.invokelatest(wp, s), sigs)
        println("K first-call checks run in the session: ", length(sigs), "; their worker's facts code from an image: ", inimg,
                "; their rule checks again: ", round(t * 1000; digits = 1), " ms")
    end
end
const _SCRIPT, _OUT = ARGS[1], ARGS[2]
empty!(ARGS); push!(ARGS, _OUT)
include(joinpath(pwd(), _SCRIPT))
