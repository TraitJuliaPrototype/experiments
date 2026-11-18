# The CodeInstances a package's closures hold after its load (C-74): the policy (flag 0x20, facts),
# from an image (0x04), G2 (0x10), and whether inferred code is present.
#   julia --project=<env> ci_flags.jl <Package> <regex on the closure type's name>
pkg = Symbol(ARGS[1]); pat = Regex(ARGS[2])
@eval using $pkg
M = getfield(Main, pkg)
function report(m::Method)
    println("method ", m.name, " in ", m.module, " policy ", ccall(:jl_method_policy, Cint, (Any,), m),
            " (0 plain, 1 facts, 2 the caller's); module flag ", ccall(:jl_get_module_facts, Cint, (Any,), m.module))
    for mi in Base.specializations(m)
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            fl = getfield(ci, :flags, :monotonic)::UInt8
            inf = getfield(ci, :inferred, :monotonic)
            println("  flags=0x", string(fl, base=16, pad=2),
                    " facts=", (fl & 0x20) != 0, " image=", (fl & 0x04) != 0, " g2=", (fl & 0x10) != 0,
                    " inferred=", inf === nothing ? "nothing" : nameof(typeof(inf)),
                    " invoke=", getfield(ci, :invoke, :monotonic) != C_NULL,
                    " worlds=", ci.min_world, ":", ci.max_world == typemax(UInt) ? "∞" : Int(ci.max_world))
            println("    ", mi.specTypes)
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
end
for name in names(M; all=true)
    s = string(name)
    startswith(s, "#") && occursin(pat, s) || continue
    T = getfield(M, name)
    T isa Type || continue
    for match in Base._methods_by_ftype(Tuple{T, Vararg{Any}}, -1, Base.get_world_counter())
        match.method.module === M && report(match.method)
    end
end
