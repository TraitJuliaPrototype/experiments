# E-205 (W-66, the store note rev 2 §6, E-a): the store's gain bound. For the CodeInstances a session makes:
# inference and optimization self-time (`time_infer_self`: exclusive of callees inferred inside) and code generation
# (`time_compile`), per owner and for the facts entries the store would admit (the note's §1); the reasons the others
# are excluded; the size of the admitted entries' optimized IR (inferred again with the facts interpreter, a sample);
# and, as a check on the per-CodeInstance sums, the session's wall clock and Julia's own compile-time counter.
#     WL_SHAPE=perturbed julia --project=<env> store_bound.jl <workload.jl> <out dir>
const NEW = Any[]
const T0 = time_ns()
const CT0 = Base.cumulative_compile_time_ns()
ccall(:jl_set_newly_inferred, Cvoid, (Any,), NEW)
const _SCRIPT, _OUT = ARGS[1], ARGS[2]
empty!(ARGS); push!(ARGS, _OUT)
include(_SCRIPT)
ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
const WALL = (time_ns() - T0) * 1e-9
const CT1 = Base.cumulative_compile_time_ns()

let
    mods = IdDict{Module,String}()
    for (id, m) in Base.loaded_modules; id.name == "Main" || (mods[m] = id.name); end
    # a module that no loaded package's root reaches is the session's (`Main`, a module defined at the prompt)
    pkgname(m::Module) = (r = Base.moduleroot(m); r === Base || r === Core ? "Julia" : get(mods, r, "session"))
    names_session(@nospecialize(x)) = _names_session(x, Base.IdSet{Any}())
    function _names_session(@nospecialize(x), seen)
        x in seen && return false
        push!(seen, x)
        if x isa Union; return _names_session(x.a, seen) || _names_session(x.b, seen)
        elseif x isa UnionAll; return _names_session(x.var.ub, seen) || _names_session(x.body, seen)
        elseif x isa TypeVar; return _names_session(x.ub, seen)
        elseif x isa Core.TypeofVararg; return isdefined(x, :T) && _names_session(x.T, seen)
        elseif x isa DataType
            pkgname(x.name.module) == "session" && return true
            return any(p -> _names_session(p, seen), x.parameters)
        end
        return false
    end
    f16(x) = Float64(reinterpret(Float16, x))
    mi_of(ci::Core.CodeInstance) = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
    cis = Core.CodeInstance[ci for ci in NEW if ci isa Core.CodeInstance]
    tinf = Dict{Any,Float64}(); tcg = Dict{Any,Float64}(); cnt = Dict{Any,Int}()
    for ci in cis
        o = ci.owner
        tinf[o] = get(tinf, o, 0.0) + f16(ci.time_infer_self)
        tcg[o] = get(tcg, o, 0.0) + f16(ci.time_compile)
        cnt[o] = get(cnt, o, 0) + 1
    end
    flush(stdout); println("Z session wall clock (workload included, from before its `using`): ", round(WALL; digits = 2), " s")
    println("Z Julia's compile-time counter: ", round((CT1[1] - CT0[1]) * 1e-9; digits = 2), " s (of it recompilation ",
            round((CT1[2] - CT0[2]) * 1e-9; digits = 2), " s)")
    println("Z CodeInstances made, by owner (count, inference self-time s, code generation s):")
    for o in keys(cnt)
        println("Z   ", rpad(string(o), 26), lpad(cnt[o], 7), "  ", round(tinf[o]; digits = 2), "  ", round(tcg[o]; digits = 2))
    end
    println("Z   sums over all owners: inference ", round(sum(values(tinf)); digits = 2), " s, code generation ",
            round(sum(values(tcg)); digits = 2), " s")
    # whether a CodeInstance reaches another owner's code, or names the session, through its edges (memoized;
    # a CodeInstance on the current path counts as neither, so cycles end)
    memo = IdDict{Core.CodeInstance,Tuple{Bool,Bool}}()
    onpath = Base.IdSet{Core.CodeInstance}()
    function reach(c::Core.CodeInstance)
        haskey(memo, c) && return memo[c]
        c in onpath && return (false, false)
        push!(onpath, c)
        o = c.owner !== :facts; s = false
        if isdefined(c, :edges)
            for e in c.edges
                if e isa Core.CodeInstance
                    eo, es = reach(e); o |= eo; s |= es
                elseif e isa Core.MethodInstance
                    s |= names_session(e.specTypes)
                elseif e isa Type
                    s |= names_session(e)
                elseif e isa Core.Binding
                    s |= pkgname(e.globalref.mod) == "session"
                end
            end
        end
        delete!(onpath, c)
        return memo[c] = (o, s)
    end
    println("Z progress: the session's CodeInstances counted, ", length(cis)); flush(stdout)
    # the facts entries, and why each excluded one is
    reasons = Dict{String,Int}()
    admitted = Core.CodeInstance[]
    for ci in cis
        ci.owner === :facts || continue
        mi = mi_of(ci); m = mi.def
        r = if !(m isa Method)
            "not a method's code (a top-level thunk)"
        elseif pkgname(m.module) == "session" || names_session(mi.specTypes)
            "names the session"
        elseif isdefined(m, :generator)
            "a generated function"
        elseif m.is_for_opaque_closure
            "an opaque closure"
        else
            o, s = reach(ci)
            s ? "an edge names the session" : o ? "reaches another owner's code" : nothing
        end
        if r === nothing
            push!(admitted, ci)
        else
            reasons[r] = get(reasons, r, 0) + 1
        end
    end
    nf = get(cnt, :facts, 0)
    ai = sum((f16(c.time_infer_self) for c in admitted); init = 0.0)
    ac = sum((f16(c.time_compile) for c in admitted); init = 0.0)
    println("Z facts CodeInstances: ", nf, "; admitted by the store: ", length(admitted))
    for (r, k) in sort!(collect(reasons); by = last, rev = true)
        println("Z   excluded, ", rpad(r, 40), lpad(k, 6))
    end
    println("Z admitted entries: inference and optimization self-time ", round(ai; digits = 2),
            " s (the bound); their code generation ", round(ac; digits = 2), " s (stays in the session)")
    flush(stdout)
    # the admitted entries' optimized IR, inferred again by the facts interpreter: a sample of up to 100
    get(ENV, "E205_IR", "0") == "1" || return nothing      # re-inference by the facts interpreter at the top level did not finish in 25 min in C
    interp = Base.Compiler.facts_interp(Base.Compiler.NativeInterpreter())
    sample = admitted[round.(Int, range(1, length(admitted); length = min(100, length(admitted))))]
    sizes = Int[]; fails = 0
    tir = @elapsed for c in sample
        mi = mi_of(c)
        try
            r = Base.code_typed_by_type(mi.specTypes; optimize = true, interp)
            isempty(r) && (fails += 1; continue)
            push!(sizes, Base.summarysize(first(first(r))))
        catch
            fails += 1
        end
    end
    if !isempty(sizes)
        mean = sum(sizes) / length(sizes)
        println("Z optimized IR of a sample of ", length(sample), " admitted entries (", fails, " not inferred again): mean ",
                round(Int, mean), " bytes, max ", maximum(sizes), "; for all admitted about ",
                round(mean * length(admitted) / 2^20; digits = 1), " MiB (", round(tir; digits = 2), " s to infer the sample again)")
    end
end
