# E-458 (a) (W-155b, D-9): the run-time sites of a package's facts code, by who owns the function they call,
# telling a run-time site (a call that records no edge, facts §5) from a fact the code dispatches when it
# runs (a call at an abstract signature that inference resolved to several methods, with their edges).
# W-152's `p5/sites.jl` (E-396) counts every dynamic call in the optimized code; on a build where an
# owner-only function's call at an abstract signature is a fact, those calls are facts but stay dynamic
# calls in the code where several methods match. This tool reads the call's inference info instead: a
# call whose info is no match (`NoCallInfo`, under an attribute's wrapper or not) is a run-time site.
#     SITES_ROOTS=CSV,DataFrames,Tables julia --project=<env> sites2.jl <package>...
for p in ARGS; Core.eval(Main, Meta.parse("using $p")); end
const C = Base.Compiler
const FACTS = 0x20
const ROOTS = Tuple(Symbol.(split(ENV["SITES_ROOTS"], ",")))
const BUDGET = parse(Float64, get(ENV, "SITES_SECONDS", "300"))
rootm(m::Module) = nameof(Base.moduleroot(m))
mis = Core.MethodInstance[]
Base.visit(Core.methodtable) do m
    rootm(m.module) in ROOTS || return
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance && isdefined(mi, :cache) || continue
        ci = mi.cache
        while true
            if ci.max_world == typemax(UInt) && ci.owner === nothing && (ci.flags & FACTS) != 0; push!(mis, mi); break; end
            isdefined(ci, :next) || break; ci = ci.next
        end
    end
end
world = Base.get_world_counter()
interp = C.NativeInterpreter(world; facts = true)
unwrapinfo(@nospecialize(i)) = i isa C.AttributedCallInfo ? unwrapinfo(i.info) : i
function argtype(ir, @nospecialize(a))
    a isa Core.SSAValue && return C.widenconst(ir.stmts.type[a.id])
    a isa Core.Argument && return C.widenconst(ir.argtypes[a.n])
    a isa GlobalRef && return isdefined(a.mod, a.name) && isconst(a.mod, a.name) ? Core.Typeof(getglobal(a.mod, a.name)) : Any
    a isa QuoteNode && return Core.Typeof(a.value)
    a isa Expr && return Any
    return Core.Typeof(a)
end
function callee(ir, @nospecialize(a))
    a isa GlobalRef && isdefined(a.mod, a.name) && isconst(a.mod, a.name) && return getglobal(a.mod, a.name)
    a isa QuoteNode && return a.value
    if a isa Core.SSAValue || a isa Core.Argument
        t = a isa Core.SSAValue ? ir.stmts.type[a.id] : ir.argtypes[a.n]
        t isa Core.Const && return t.val
    end
    (a isa Function || a isa Type) && return a
    return nothing
end
counts = Dict{String,Int}(); examples = Dict{String,Vector{String}}()
done = 0; dyn = 0; rts = 0; facts_dyn = 0; failed = 0; t0 = time()
for mi in mis
    time() - t0 > BUDGET && break
    r = try Base.code_ircode_by_type(mi.specTypes; interp) catch; nothing end
    (r === nothing || length(r) != 1 || !(r[1][1] isa C.IRCode)) && (global failed += 1; continue)
    ir = r[1][1]; global done += 1
    for i in 1:length(ir.stmts)
        st = ir.stmts.stmt[i]
        st isa Expr && st.head === :call || continue
        f = callee(ir, st.args[1])
        (f isa Core.Builtin || f isa Core.IntrinsicFunction) && continue
        global dyn += 1
        info = unwrapinfo(ir.stmts.info[i])
        if !(info isa C.NoCallInfo)
            global facts_dyn += 1      # a fact dispatched when it runs: its matches and edges are recorded
            continue
        end
        global rts += 1
        k = if f === nothing
            "the callee is not a constant (a called value)"
        else
            ft = Core.Typeof(f)
            om = f isa Type ? parentmodule(Base.unwrap_unionall(f) isa DataType ? Base.unwrap_unionall(f).name.module : Core) : parentmodule(f)
            name = f isa Type ? (Base.unwrap_unionall(f) isa DataType ? Base.unwrap_unionall(f).name.name : :Type) : nameof(f)
            own = rootm(om) in ROOTS
            pub = try Base.ispublic(om, name) catch; false end
            oo = f isa Function && C.is_owner_only(ft)
            if oo
                at = Any[argtype(ir, a) for a in st.args[2:end]]
                sig = try Tuple{ft, at...} catch; nothing end
                mm = sig === nothing ? nothing : Base._methods_by_ftype(sig, -1, world)
                nm = mm === nothing ? -1 : length(mm)
                nm > 3 ? "an owner-only function (D-9), more methods match than Julia's max_methods" :
                         "an owner-only function (D-9), $(nm < 0 ? "signature not formed" : "at most three methods match")"
            elseif own && !pub
                "own function, not public, not owner-only (its module's `owner_only` option is off)"
            elseif own
                "own function, public or exported"
            elseif rootm(om) in (:Base, :Core)
                "Base's or Core's function"
            else
                "another package's function"
            end
        end
        counts[k] = get(counts, k, 0) + 1
        ex = get!(examples, k, String[]); length(ex) < 6 && push!(ex, first(string(f, " in ", mi.def.name, " [", basename(string(mi.def.file)), ":", mi.def.line, "]"), 140))
    end
end
println("roots ", join(ROOTS, ","), " | own facts instances ", length(mis), ", inferred again ", done, " (failed ", failed, ") in ",
        round(time() - t0; digits = 1), " s | dynamic calls ", dyn, ": run-time sites (no edge) ", rts, ", facts dispatched when they run ", facts_dyn)
for (k, v) in sort(collect(counts); by = last, rev = true)
    println(lpad(v, 6), "  ", lpad(round(100v / max(rts, 1); digits = 1), 5), " %  ", k)
    for e in examples[k]; println("             ", e); end
end
