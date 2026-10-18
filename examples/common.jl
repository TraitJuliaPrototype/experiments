# Shared helpers for the examples and the framing acceptance cases: checks with stated expected
# outcomes, and counts of CodeInstances by module through Julia's own reflection (no TraitWorld
# machinery). Include it first: `include(joinpath(@__DIR__, "..", "common.jl"))` or the right path.

const RESULTS = Tuple{String,Symbol,String}[]      # (name, :pass | :fail | :pending, detail)

"Record a check: `ok` against the outcome the design predicts."
function check(name::AbstractString, ok::Bool, detail::AbstractString = "")
    push!(RESULTS, (name, ok ? :pass : :fail, detail))
    println(ok ? "PASS     " : "FAIL     ", name, isempty(detail) ? "" : "  ($detail)")
    return ok
end

"Record an outcome that depends on a part not built yet: what is seen today, and on what it waits."
function pending(name::AbstractString, waits_on::AbstractString, seen::AbstractString = "")
    push!(RESULTS, (name, :pending, waits_on))
    println("PENDING  ", name, "  [waits on: ", waits_on, "]", isempty(seen) ? "" : "  today: " * seen)
    return nothing
end

"Print the tally; exit with 1 if a check failed (pending checks do not fail a run)."
function summary()
    np = count(r -> r[2] === :pass, RESULTS); nf = count(r -> r[2] === :fail, RESULTS)
    nq = count(r -> r[2] === :pending, RESULTS)
    println("\n", np, " pass, ", nf, " fail, ", nq, " pending")
    nf > 0 && exit(1)
    return nothing
end

"The value or the exception of `f()`, with LoadErrors unwrapped."
function outcome(f)
    try
        return f()
    catch e
        while e isa LoadError; e = e.error; end
        return e
    end
end
toplevel(ex) = Core.eval(Main, ex isa Expr && ex.head === :block ? Expr(:toplevel, ex.args...) : ex)

"Every CodeInstance of every method, any owner."
function allcis()
    out = Core.CodeInstance[]
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                push!(out, ci); isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    return out
end
_cimodule(ci) = (mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def; mi.def isa Method ? mi.def.module : nothing)
_within(m, root::Module) = m isa Module && (m === root || (p = parentmodule(m); p !== m && _within(p, root)))
"The valid CodeInstances (any owner) of methods defined in `root` or its submodules."
valid_cis(root::Module) = filter(ci -> ci.max_world == typemax(UInt) && _within(_cimodule(ci), root), allcis())
"How many of `cis` are no longer valid."
nlost(cis) = count(ci -> ci.max_world != typemax(UInt), cis)

"All CodeInstances of `f` at exactly the argument types `types`, with validity (the S1–S8 probe)."
function cis_at(f, types)
    sig = Tuple{typeof(f), types...}
    out = Core.CodeInstance[]
    for m in methods(f), mi in Base.specializations(m)
        mi isa Core.MethodInstance && mi.specTypes === sig || continue
        isdefined(mi, :cache) || continue
        ci = mi.cache
        while true
            push!(out, ci); isdefined(ci, :next) || break; ci = ci.next
        end
    end
    return out
end
"Whether the compiler runs in facts mode in this process (the in-tree mode, `JULIA_COMPILE_BY_FACTS=1`)."
facts_mode() = isdefined(Base.Compiler.NativeInterpreter(), :facts) && Base.Compiler.NativeInterpreter().facts
"Count the frames of a backtrace that are not Julia's own top level."
nframes(bt) = length(Base.stacktrace(bt))
