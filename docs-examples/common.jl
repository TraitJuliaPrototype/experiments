# Helpers for the documentation examples: checks with a stated expectation, and the
# evaluation of statements that must fail (as TraitWorld/test/runtests.jl does it).

using Test: Test

const RESULTS = Tuple{String,Bool}[]

"Record a check: `ok` is the outcome the documentation states."
function check(name::AbstractString, ok::Bool)
    push!(RESULTS, (name, ok))
    println(ok ? "PASS  " : "FAIL  ", name)
    return ok
end

"Evaluate `ex` at top level in Main (modules, structs and macros allowed)."
toplevel(ex) = Core.eval(Main, ex isa Expr && ex.head === :block ? Expr(:toplevel, ex.args...) : ex)

"Evaluate `ex` like `toplevel` and return the exception it throws (LoadErrors unwrapped), or `nothing`."
function thrown(ex)
    try
        toplevel(ex)
        return nothing
    catch e
        while e isa LoadError
            e = e.error
        end
        return e
    end
end

"The value of `f()`, or the exception it throws."
function outcome(f)
    try
        return Base.invokelatest(f)
    catch e
        while e isa LoadError
            e = e.error
        end
        return e
    end
end

"The message of an exception, as `showerror` prints it."
msg(e) = e isa Exception ? sprint(showerror, e) : string(e)

"Evaluate `ex` like `toplevel` and return the log records it emits, and the exception it throws or `nothing`."
function logs_of(ex)
    logs, e = Test.collect_test_logs() do
        thrown(ex)
    end
    return logs, e
end
warned(logs, pat) = any(l -> l.level == Base.CoreLogging.Warn && occursin(pat, string(l.message)), logs)

"Print the tally; exit with 1 if a check failed."
function summary()
    np = count(r -> r[2], RESULTS)
    nf = length(RESULTS) - np
    println("\n", np, " pass, ", nf, " fail")
    nf > 0 && exit(1)
    return nothing
end
