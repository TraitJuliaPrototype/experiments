# E-172: an emulated cache across sessions: the statements a perturbed session compiled (trace.jl), those that
# do not name Main, compiled into this package's image.
module SessionCacheSci
using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, CairoMakie, Serialization
for (id, m) in Base.loaded_modules
    n = Symbol(id.name)
    isdefined(@__MODULE__, n) || Core.eval(@__MODULE__, :(const $n = $m))
end
"Compile the method instance of signature `T` for the facts owner (a statement recorded from facts code, E-175)."
function fpc(@nospecialize(T))
    w = Base.get_world_counter()
    ms = Base._methods_by_ftype(T, 1, w)
    (ms isa Vector && length(ms) == 1) || return false
    mi = Base.Compiler.specialize_method(ms[1])
    ci = Base.Compiler.typeinf_ext_toplevel(mi, w, Base.Compiler.SOURCE_MODE_ABI, Base.Compiler.TRIM_NO, Base.Compiler.FACTS_OWNER)
    return ci !== nothing
end
"Run a worker signature's first-call check now and keep its result in this package's image (TraitWorld's ahead checks)."
checked(@nospecialize(T)) = (isdefined(@__MODULE__, :TraitWorld) && TraitWorld._check_ahead!(@__MODULE__, nothing, T); true)
include_dependency(joinpath(@__DIR__, "trace.jl"))   # the statements are this package's source too
isfile(joinpath(@__DIR__, "trace.jls")) && include_dependency(joinpath(@__DIR__, "trace.jls"))
const COUNTS = isfile(joinpath(@__DIR__, "trace.jls")) ? let r = Serialization.deserialize(joinpath(@__DIR__, "trace.jls")), ok = 0, failed = 0
    for T in r.plain;  (try precompile(T) catch; false end) ? (ok += 1) : (failed += 1); end
    for T in r.facts;  (try fpc(T) catch; false end) ? (ok += 1) : (failed += 1); end
    for T in r.checks; (try checked(T) catch; false end) ? (ok += 1) : (failed += 1); end
    (ok = ok, failed = failed, skipped = 0, source = :jls)
end : let ok = 0, failed = 0, skipped = 0
    for line in eachline(joinpath(@__DIR__, "trace.jl"))
        (startswith(line, "precompile") || startswith(line, "fpc") || startswith(line, "checked")) || continue
        if occursin("Main.", line); skipped += 1; continue; end
        r = try Core.eval(@__MODULE__, Meta.parse(line)) catch; false end
        r === true ? (ok += 1) : (failed += 1)
    end
    (ok = ok, failed = failed, skipped = skipped)
end
end
