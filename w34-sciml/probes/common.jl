# Shared by the E-156 probes: the setting line, top-level evaluation, and the result line.
# Each probe runs in a fresh session (run_probes.sh). Modules defined directly under Main stand in
# for packages: each is an owner of its own (traits reference §10.1).
using TraitWorld, Printf

const TW_COMMIT = let d = pkgdir(TraitWorld)
    c = try readchomp(`git -C $d rev-parse --short HEAD`) catch; "?" end
    dirty = try !isempty(readchomp(`git -C $d status --porcelain --untracked-files=no`)) catch; false end
    dirty ? c * "+changes" : c
end
const SETTING = Base.Compiler.NativeInterpreter().facts ? "all" : "product"
loadavg() = join(first(split(read("/proc/loadavg", String)), 3), " ")

function header(probe, form)
    println("== E-156 probe ", probe)
    println("   julia ", VERSION, " (", Base.GIT_VERSION_INFO.commit_short, ")  TraitWorld ", TW_COMMIT,
            "  setting ", SETTING, "  strict ", TraitWorld.STRICT[] ? "on" : "off", "  threads ", Threads.nthreads())
    println("   load (cut -d' ' -f1-3 /proc/loadavg) at start: ", loadavg())
    println("   form: ", form)
    println()
end

"Evaluate a quoted block at Main's top level, statement by statement (each sees the previous)."
toplevel(ex) = Core.eval(Main, ex isa Expr && ex.head === :block ? Expr(:toplevel, ex.args...) : ex)
inner_err(e) = (while e isa LoadError; e = e.error; end; e)
"Run `f`; `nothing` if it returns, else the innermost exception."
caught(f) = try f(); nothing catch e; inner_err(e) end
"The exception's type and its first lines of text."
function errtext(e; lines = 6)
    e === nothing && return "no exception"
    s = try sprint(showerror, e) catch; string(e) end
    ls = split(s, '\n')
    string(typeof(e), ": ", join(ls[1:min(lines, length(ls))], "\n      "), length(ls) > lines ? "\n      …" : "")
end

const CHECKS = Tuple{String,Bool,String}[]
"One observation: `ok` is whether it matches what the reference says."
function check(name::AbstractString, ok::Bool, detail::AbstractString = "")
    push!(CHECKS, (String(name), ok, String(detail)))
    @printf("  [%s] %s\n", ok ? "ok  " : "FAIL", name)
    isempty(detail) || println("         ", replace(detail, "\n" => "\n         "))
    return ok
end

"""
The probe's summary and its last line, `RESULT <probe> PASS|FAIL|ERROR`.
PASS: every check matches what the reference says (its status and its Deviations table).
`prediction`: whether the observed behaviour matches the plan's prediction by reading.
"""
function finish(probe; predicted, reference, prediction::AbstractString, observed::AbstractString = "")
    allok = all(c -> c[2], CHECKS)
    println()
    println("predicted (plan §2.1): ", predicted)
    println("reference says:        ", reference)
    isempty(observed) || println("observed:              ", observed)
    println("matches the prediction: ", prediction)
    println("load at end: ", loadavg())
    println("RESULT ", probe, " ", isempty(CHECKS) ? "ERROR" : allok ? "PASS" : "FAIL")
end

"Per-call cost of `f(n)` running `n` calls: warm up, then the best of `reps` timings, and bytes per call."
function percall(f, n::Int; reps::Int = 5)
    f(10); f(10)
    best = typemax(UInt64)
    for _ in 1:reps
        t0 = time_ns(); f(n); best = min(best, time_ns() - t0)
    end
    bytes = @allocated f(n)
    return (ns = best / n, bytes = bytes / n)
end
