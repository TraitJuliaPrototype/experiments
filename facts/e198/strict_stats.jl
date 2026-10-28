# E-198 part A: strict mode's statistics at the workload's load mark: methods seen, pirates walked, seconds
# owning and walking (`TraitWorld._STRICT_STATS`), the safety net's misses, and the pirates reported at loads.
#     JULIA_TW_STRICT=1 julia --project=<env> strict_stats.jl <workload script> <outdir>   (from experiments/ttfx)
function _on_mark(step)
    step == "load" || return
    TW = Base.loaded_modules[Base.PkgId(Base.UUID("7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"), "TraitWorld")]
    st = getglobal(TW, :_STRICT_STATS)
    lp = isdefined(TW, :_LOAD_PIRATES) ? length(getglobal(TW, :_LOAD_PIRATES)) : -1
    println("Q strict ", getglobal(TW, :STRICT)[], " methods seen ", Int(st[1]), ", pirates walked ", Int(st[2]),
            ", owning ", round(st[3]; digits = 2), " s, walking ", round(st[4]; digits = 2), " s; safety-net misses ",
            length(getglobal(TW, :_STRICT_MISSES)), "; pirates reported at loads ", lp)
end
const _SCRIPT, _OUT = ARGS[1], ARGS[2]
empty!(ARGS); push!(ARGS, _OUT)
include(joinpath(pwd(), _SCRIPT))
