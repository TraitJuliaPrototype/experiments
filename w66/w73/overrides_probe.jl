# W-73 (e): the cost of the override checkpoint that every first-call check runs (`check_overrides()`), at the
# end of a session: the declarations it scans and its time, best of five.
#     julia --project=<env> overrides_probe.jl <workload script> <outdir>   (from experiments/ttfx)
const TWID = Base.PkgId(Base.UUID("7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"), "TraitWorld")
function _on_mark(step)
    step == "again" || return
    TW = Base.loaded_modules[TWID]
    co = getglobal(TW, :check_overrides)
    Base.invokelatest(co)
    t = minimum(@elapsed(Base.invokelatest(co)) for _ in 1:5)
    n = length(methods(getglobal(TW, :_declared_defaults)))
    println("O check_overrides: ", round(t * 1e6; digits = 1), " µs over ", n, " declarations")
end
const _SCRIPT, _OUT = ARGS[1], ARGS[2]
empty!(ARGS); push!(ARGS, _OUT)
include(joinpath(pwd(), _SCRIPT))
