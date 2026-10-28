# A/B probes (W-85): measurements in this process, printed as lines the harness (ab.sh) reads:
#     AB <name> key=value …
# `abmeasure(name, f)` measures `f()`: `first_*` is the first call with its compilation (Julia's compile-time
# counter, its recompilation part, and the CodeInstances inferred); `steady_*` the minimum of `runs` calls after
# two warm-ups, and the bytes, allocations and GC time of one. With `per = n` (`f` makes `n` calls itself) the
# steady time and bytes are also given per call (`call_ns`, `call_bytes`).
# `abreport(name; key = value, …)` prints any other numbers (a load time, a count).
module ABProbe
export abmeasure, abreport

function abreport(name::AbstractString; kv...)
    print("AB ", name)
    for (k, v) in kv
        print(" ", k, "=", v isa AbstractFloat ? round(v; sigdigits = 6) : v)
    end
    println()
    flush(stdout)
    return nothing
end

function abmeasure(name::AbstractString, f; runs::Int = 5, per::Int = 1)
    Base.cumulative_compile_timing(true)
    new = Any[]
    ccall(:jl_set_newly_inferred, Cvoid, (Any,), new)
    c0 = Base.cumulative_compile_time_ns()
    t1 = @elapsed f()
    c1 = Base.cumulative_compile_time_ns()
    ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
    Base.cumulative_compile_timing(false)
    ncis = count(x -> x isa Core.CodeInstance, new)
    f(); f()
    ts = minimum(@elapsed(f()) for _ in 1:runs)
    st = @timed f()
    kv = Pair{Symbol,Any}[:first_ms => t1 * 1e3, :first_compile_ms => (c1[1] - c0[1]) / 1e6,
                          :first_recompile_ms => (c1[2] - c0[2]) / 1e6, :first_cis => ncis,
                          :steady_ms => ts * 1e3, :steady_bytes => st.bytes, :steady_allocs => Base.gc_alloc_count(st.gcstats),
                          :steady_gc_ms => st.gctime * 1e3]
    per > 1 && append!(kv, [:call_ns => ts * 1e9 / per, :call_bytes => st.bytes / per])
    abreport(name; kv...)
    return nothing
end
end
