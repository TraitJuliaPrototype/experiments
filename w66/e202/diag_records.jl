# E-203 diagnosis: for each first-call check run in the session, the modules searched, their records, and
# whether the worker method was definition-checked.
const TWID = Base.PkgId(Base.UUID("7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"), "TraitWorld")
function _on_mark(step)
    step == "again" || return
    TW = Base.loaded_modules[TWID]
    for sig in getglobal(TW, :_CHECKED_IN_SESSION)
        mods = getglobal(TW, :_record_modules)(sig)
        ws = getglobal(TW, :_worker_methods)(sig)
        println("G ", first(string(sig), 200))
        println("G   worker methods: ", [string(m.module, ".", m.name, " ", m.sig) for m in ws])
        println("G   def-checked: ", [getglobal(TW, :_was_def_checked)(m) for m in ws], "; _def_checked(sig) ", getglobal(TW, :_def_checked)(sig))
        for m in mods
            isdefined(m, :__tw_checked__) || continue
            rs = getglobal(m, :__tw_checked__)
            println("G   ", m, ": ", length(rs), " records; same sig: ", count(e -> e isa Tuple && e[1] == sig, rs))
        end
        for m in unique([w.module for w in ws])
            println("G   ", m, " __tw_def_checked__: ", isdefined(m, :__tw_def_checked__) ? length(getglobal(m, :__tw_def_checked__)) : "none")
        end
    end
end
const _SCRIPT, _OUT = ARGS[1], ARGS[2]
empty!(ARGS); push!(ARGS, _OUT)
include(joinpath(pwd(), _SCRIPT))
