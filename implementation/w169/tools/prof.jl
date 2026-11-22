# W-169 (E-536): one session, cut into phases at lines `#@ name`, each evaluated at top level in this one process,
# as at a prompt. E-388's runner (`../../w145/profile/prof.jl`) with the classes the round asks for. Modes (W169_MODE):
#   time   each phase timed, with Julia's own counters: compile time and of it compiled again
#          (`Base.cumulative_compile_time_ns`), the collector's time and allocations (`Base.gc_num`)
#   prof   each phase under the sampling profiler (C frames; W169_DELAY, default 0.001 s); every sample of the main
#          thread that is not sleeping is given to one class (CLASSES, the first that matches anywhere on its stack)
#   inval  Julia's invalidation log on from the first phase to the last (`jl_debug_method_invalidation`); its entries
#          summarized by kind and by cause (tools/invalidations.jl)
# Every mode prints `START <unix time>` first and `END <unix time>` last, so that the driver can tell Julia's start
# (from the process's exec to the script's first line) and its exit from the session.
# A phase whose name starts with `_` runs untimed and unprofiled (definitions the session needs).
#     julia --project=<env> prof.jl <session.jl>
println("START ", time())
get(ENV, "W169_HARNESS", "0") == "1" && println(stderr, "H start ", time())
const MODE = get(ENV, "W169_MODE", "time")
const SESSION = abspath(ARGS[1])
# W169_LLVM=<file>: every code generation of the process with its time (`jl_dump_compiles`: ns, then the instance's
# signature), from here to the end. W169_CENSUS=<file>: tools/census.jl at the end.
const LLVMIO = haskey(ENV, "W169_LLVM") ? open(ENV["W169_LLVM"], "w") : nothing
LLVMIO === nothing || ccall(:jl_dump_compiles, Cvoid, (Ptr{Cvoid},), LLVMIO.handle)
haskey(ENV, "W169_CENSUS") && (include(joinpath(@__DIR__, "census.jl")); const CENSUS0 = Base.invokelatest(census, "/dev/null"; label = "CENSUS0"))

# ---- the driver: a function whose modes are constants, so that it is compiled without the other modes' branches
# (a loop at top level is compiled whole, with every branch of every mode: 0.4 s). Its time is what the phases leave
# of the script's time ("the harness" in tools/split.py); the profile's report runs after each phase, through
# `invokelatest`, outside every timed or profiled window.
module W169H
const SESSION = Main.SESSION
const PROF = Main.MODE == "prof"
const INVAL = Main.MODE == "inval"
const KEEP = get(ENV, "W169_STDOUT", "0") == "1"     # keep the session's output (NetworkDynamics' workload prints its times)
function phases(file)
    out = Pair{String,String}[]; name = "_head"; buf = IOBuffer()
    for l in eachline(file)
        if startswith(l, "#@ ")
            push!(out, name => String(take!(buf))); name = String(strip(l[4:end]))
        else
            println(buf, l)
        end
    end
    push!(out, name => String(take!(buf)))
    return out
end
run_phase(text) = KEEP ? include_string(Main, text, SESSION) : redirect_stdout(devnull) do; include_string(Main, text, SESSION); end
r2(x) = round(x; digits = 2)
function drive()
    Base.cumulative_compile_timing(true)
    for (name, text) in phases(SESSION)
        isempty(strip(text)) && continue
        Main.LLVMIO === nothing || (println(Main.LLVMIO, "PHASE\t", name); flush(Main.LLVMIO))   # the phases in the dump
        if startswith(name, "_")
            include_string(Main, text, SESSION)
        elseif PROF
            push!(Main.PHASEDATA, name => Base.invokelatest(Main.profphase, text))
        else
            n0 = INVAL ? length(Main.ILOG) : 0
            g0 = Base.gc_num(); c0 = Base.cumulative_compile_time_ns(); t0 = time_ns()
            run_phase(text)
            t1 = time_ns(); c1 = Base.cumulative_compile_time_ns(); g = Base.GC_Diff(Base.gc_num(), g0)
            println(string("P\t", name, "\t", r2((t1 - t0) / 1e6), "\tcompile ", r2((c1[1] - c0[1]) / 1e6),
                    "\tagain ", r2((c1[2] - c0[2]) / 1e6), "\tgc ", r2(g.total_time / 1e6),
                    "\talloc_mb ", r2(g.allocd / 2^20), "\tgc_full ", g.full_sweep, "\tgc_n ", g.pause))
            INVAL && println(string("I\t", name, "\tlog entries ", length(Main.ILOG) - n0))
        end
    end
    Base.cumulative_compile_timing(false)
end
end

get(ENV, "W169_HARNESS", "0") == "1" && println(stderr, "H defs ", time())
if MODE == "prof"
    include(joinpath(@__DIR__, "classes.jl"))      # the classes and the report: read only when profiling
    ccall(:jl_profile_init, Cint, (Csize_t, UInt64), 4 * 10^7, round(UInt64, 1e9 * parse(Float64, get(ENV, "W169_DELAY", "0.001"))))
    const PHASEDATA = Pair{String,Tuple{Float64,Vector{UInt}}}[]
    function profphase(text)     # the phase's raw samples, kept; classed after the session (report_all)
        ccall(:jl_profile_clear_data, Cvoid, ())
        t0 = time_ns()
        ccall(:jl_profile_start_timer, Cint, (Bool,), false)
        try
            W169H.run_phase(text)
        finally
            ccall(:jl_profile_stop_timer, Cvoid, ())
        end
        t = (time_ns() - t0) / 1e9
        n = Int(ccall(:jl_profile_len_data, Csize_t, ()))
        d = copy(unsafe_wrap(Array, convert(Ptr{UInt}, ccall(:jl_profile_get_data, Ptr{UInt8}, ())), (n,)))
        return t, d
    end
    report_all() = for (name, (t, d)) in PHASEDATA; report(name, t, d); end
    profphase("nothing")         # the profiler's own first use
elseif MODE == "inval"
    include(joinpath(@__DIR__, "invalidations.jl"))
    const ILOG = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
end
final_inval() = (ccall(:jl_debug_method_invalidation, Any, (Cint,), 0); Base.invokelatest(summarize_invalidations, stdout, ILOG))
W169TIMES = get(ENV, "W169_HARNESS", "0") == "1"      # where the harness's own time goes (to stderr)
W169TIMES && println(stderr, "H before drive ", time())
W169H.drive()
W169TIMES && println(stderr, "H after drive ", time())
MODE == "prof" && (Base.invokelatest(report_all); final_prof())
MODE == "inval" && final_inval()
println("END ", time())
LLVMIO === nothing || (ccall(:jl_dump_compiles, Cvoid, (Ptr{Cvoid},), C_NULL); close(LLVMIO))
haskey(ENV, "W169_CENSUS") && Base.invokelatest(census, ENV["W169_CENSUS"]; exclude = CENSUS0)
exit(0)      # a program's `(@main)` is not run again at the script's end
