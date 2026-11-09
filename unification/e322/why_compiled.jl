# E-322: why the goal's task compiles TraitWorld's check code although its images hold G2 copies.
#   cd TraitReport-unified && julia --project=env_fu why_compiled.jl <script> <args…>
# Logs insertions and image validation through the script's run; prints the entries that name the check code,
# and the worlds of each CodeInstance of `_sig_alternatives(Any, Int64)` at the end.
ins = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
val = Base.Compiler.ReinferUtils.debug_method_invalidation(true)
script = abspath(popfirst!(ARGS))
include(script)
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
Base.Compiler.ReinferUtils.debug_method_invalidation(false)
println("insertion log: ", length(ins), " entries; validation log: ", length(val), " entries")
const NAMES = ("_sig_alternatives", "_check_contract!", "_check_pattern_member", "check_first_use", "_owners!", "sig_owners")
hit(x) = any(n -> occursin(n, string(x)), NAMES)
for (tag, log) in (("INSERT", ins), ("VALIDATE", val))
    for (i, x) in enumerate(log)
        (x isa Core.MethodInstance || x isa Core.CodeInstance) && hit(x) || continue
        ctx = [first(sprint(show, log[j]), 200) for j in i+1:min(i+3, length(log))]
        println(tag, " ", first(string(x), 160), "\n    then: ", join(ctx, " | "))
    end
end
const TW = only(m for m in values(Base.loaded_modules) if nameof(m) === :TraitWorld)
println("world now ", Base.get_world_counter())
for m in methods(TW._sig_alternatives), mi in Base.specializations(m)
    ci = isdefined(mi, :cache) ? mi.cache : nothing
    while ci !== nothing
        fl = getfield(ci, :flags, :monotonic)::UInt8
        ci.owner === nothing && println(mi.specTypes, " worlds ", ci.min_world, "-", ci.max_world == typemax(UInt) ? "∞" : ci.max_world,
            " facts=", (fl & 0x20) != 0, " G2=", (fl & 0x10) != 0, " image=", (fl & 0x04) != 0, " edges=", length(ci.edges))
        ci = isdefined(ci, :next) ? ci.next : nothing
    end
end
