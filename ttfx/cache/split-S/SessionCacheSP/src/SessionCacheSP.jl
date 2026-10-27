# E-177: one part of an emulated cache split by dependency set: the types recorded in trace.jls, compiled here.
module SessionCacheSP
using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, CairoMakie, Serialization
for (id, m) in Base.loaded_modules
    n = Symbol(id.name)
    isdefined(@__MODULE__, n) || Core.eval(@__MODULE__, :(const $n = $m))
end
function fpc(@nospecialize(T))
    w = Base.get_world_counter()
    ms = Base._methods_by_ftype(T, 1, w)
    (ms isa Vector && length(ms) == 1) || return false
    mi = Base.Compiler.specialize_method(ms[1])
    return Base.Compiler.typeinf_ext_toplevel(mi, w, Base.Compiler.SOURCE_MODE_ABI, Base.Compiler.TRIM_NO, Base.Compiler.FACTS_OWNER) !== nothing
end
checked(@nospecialize(T)) = (isdefined(@__MODULE__, :TraitWorld) && TraitWorld._check_ahead!(@__MODULE__, nothing, T); true)
include_dependency(joinpath(@__DIR__, "trace.jls"))
const COUNTS = let r = Serialization.deserialize(joinpath(@__DIR__, "trace.jls")), ok = 0, failed = 0
    for T in r.plain;  (try precompile(T) catch; false end) ? (ok += 1) : (failed += 1); end
    for T in r.facts;  (try fpc(T) catch; false end) ? (ok += 1) : (failed += 1); end
    for T in r.checks; (try checked(T) catch; false end) ? (ok += 1) : (failed += 1); end
    (ok = ok, failed = failed)
end
end
