# E-234: an emulated cache across sessions: the types a session compiled after its load (rec.jl's recording,
# trace.jls), compiled into this package's image.
module SessionCacheTR
using TraitCSV, TraitTables, TraitMakie, TraitWorld, Serialization
"Compile the method instance of signature `T` for the facts owner (a recorded facts CodeInstance, E-175)."
function fpc(@nospecialize(T))
    w = Base.get_world_counter()
    ms = Base._methods_by_ftype(T, 1, w)
    (ms isa Vector && length(ms) == 1) || return false
    mi = Base.Compiler.specialize_method(ms[1])
    ci = Base.Compiler.typeinf_ext_toplevel(mi, w, Base.Compiler.SOURCE_MODE_ABI, Base.Compiler.TRIM_NO, Base.Compiler.FACTS_OWNER)
    return ci !== nothing
end
"Run a worker signature's first-call check now and keep its result in this package's image (TraitWorld's ahead checks)."
checked(@nospecialize(T)) = (TraitWorld._check_ahead!(@__MODULE__, nothing, T); true)
include_dependency(joinpath(@__DIR__, "trace.jls"))
des(b) = try Serialization.deserialize(IOBuffer(b)) catch; nothing end
const COUNTS = let r = Serialization.deserialize(joinpath(@__DIR__, "trace.jls")), ok = 0, failed = 0, unread = 0
    for (f, v) in ((precompile, r.plain), (fpc, r.facts), (checked, r.checks)), b in v
        T = des(b)
        T === nothing && (unread += 1; continue)
        (try f(T) catch; false end) === true ? (ok += 1) : (failed += 1)
    end
    (ok = ok, failed = failed, unread = unread)
end
end
