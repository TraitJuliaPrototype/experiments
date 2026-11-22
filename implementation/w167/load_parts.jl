# W-167 (open issue 255): a port's load in parts, each counted apart without a profiler.
#     julia --project=<env> load_parts.jl <walk|nowalk> <Pkg> [<Pkg> ...]
# The library is loaded first (as a port's session does). Then, around `using <Pkg>...`:
#   - the library's image hook (compiler §10.1), timed through a wrapper installed in its place (calls, ms);
#   - each package callback (strict mode's and the report's, after each package's load), timed the same way;
#   - Julia's compile timer: compiling, and of it compiling again code that was invalidated;
#   - "nowalk": the membership walk lowers the dispatch caches and invalidates no code (w145/loads/load.jl's control;
#     answers can be wrong after it: nothing is run).
# The rest is the image's restore, its methods' and memberships' activation and the walk, the validation of its
# code, and the code generation that the compile timer does not count.
mode = popfirst!(ARGS)
mode == "nowalk" && ccall(:jl_set_membership_walk_invalidates, Cint, (Cint,), 0)
# W167_LOG=1: Julia's invalidation log on during the load, as w145/loads/load.jl has it (its cost is in the total)
const LOGON = get(ENV, "W167_LOG", "0") == "1"
t_tw = @elapsed using TraitWorld
const T_HOOK = Ref(UInt64(0)); const N_HOOK = Ref(0)
const T_CB = Dict{Symbol,UInt64}(); const N_CB = Dict{Symbol,Int}()
const HOOK = isdefined(TraitWorld, :_image_methods_hook) ? TraitWorld._image_methods_hook : nothing   # the tag's library has none
function timed_hook(ms::Vector{Any}, pkg::String)
    t = time_ns()
    try
        return HOOK(ms, pkg)
    finally
        T_HOOK[] += time_ns() - t; N_HOOK[] += 1
    end
end
struct TimedCallback; f::Any; name::Symbol; end
function (c::TimedCallback)(pkg)
    t = time_ns()
    try
        return c.f(pkg)
    finally
        T_CB[c.name] = get(T_CB, c.name, UInt64(0)) + (time_ns() - t); N_CB[c.name] = get(N_CB, c.name, 0) + 1
    end
end
precompile(timed_hook, (Vector{Any}, String)); precompile(TimedCallback(identity, :x), (Base.PkgId,))
HOOK === nothing || ccall(:jl_set_image_methods_hook, Cvoid, (Any,), timed_hook)
for i in eachindex(Base.package_callbacks)
    f = Base.package_callbacks[i]
    Base.package_callbacks[i] = TimedCallback(f, Symbol(f))
end
Base.cumulative_compile_timing(true)
c0 = Base.cumulative_compile_time_ns()
LOGON && (ilog = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1))
t = @elapsed for p in ARGS
    @eval using $(Symbol(p))
end
LOGON && ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
c1 = Base.cumulative_compile_time_ns()
Base.cumulative_compile_timing(false)
ms(x) = round(x / 1e6; digits = 1)
cb = join([string(k, " ", ms(v), " ms (", N_CB[k], ")") for (k, v) in sort(collect(T_CB); by = first)], ", ")
println("LOADPARTS ", mode, LOGON ? " log" : "", " ", join(ARGS, "+"), " | total ", round(1000t; digits = 1), " ms | image hook ", ms(T_HOOK[]),
        " ms (", N_HOOK[], " images) | callbacks ", cb, " | compiling ", ms(c1[1] - c0[1]), " ms, of it again ", ms(c1[2] - c0[2]),
        " ms | TraitWorld first ", round(1000t_tw; digits = 1), " ms | ", pathof(TraitWorld))
