# E-396 (W-152; the review of 2026-11-15, P5 (b)): the run-time sites of a package's facts code, by who owns
# the function they call. A function that only its owner may extend (neither exported nor public, every
# method in its owner's package) would make such a call a fact.
#     SITES_ROOTS=CSV,DataFrames,Tables julia --project=<env> sites.jl <package>...
# Each own facts instance in the session is inferred again by the facts rule (the top frame; its callees keep
# their policy) and its optimized code is read for calls left to run time.
for p in ARGS; Core.eval(Main, Meta.parse("using $p")); end
const C = Base.Compiler
const FACTS = 0x20
const ROOTS = Tuple(Symbol.(split(ENV["SITES_ROOTS"], ",")))
const BUDGET = parse(Float64, get(ENV, "SITES_SECONDS", "240"))
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
argtype(src, @nospecialize(a)) =
    a isa Core.SSAValue ? C.widenconst(src.ssavaluetypes[a.id]) :
    a isa Core.Argument ? C.widenconst(src.slottypes[a.n]) :
    a isa Core.SlotNumber ? C.widenconst(src.slottypes[a.id]) :
    a isa GlobalRef ? (isdefined(a.mod, a.name) && isconst(a.mod, a.name) ? Core.Typeof(getglobal(a.mod, a.name)) : Any) :
    a isa QuoteNode ? Core.Typeof(a.value) : a isa Expr ? Any : Core.Typeof(a)
function callee(src, @nospecialize(a))
    a isa GlobalRef && isdefined(a.mod, a.name) && isconst(a.mod, a.name) && return getglobal(a.mod, a.name)
    a isa QuoteNode && return a.value
    (a isa Core.SSAValue || a isa Core.Argument) && (t = a isa Core.SSAValue ? src.ssavaluetypes[a.id] : src.slottypes[a.n]; t isa Core.Const && return t.val)
    (a isa Function || a isa Type) && return a
    nothing
end
counts = Dict{String,Int}(); typed = Dict{String,Int}(); examples = Dict{String,Vector{String}}()
ownfuns = Dict{String,Int}()
done = 0; sites = 0; t0 = time(); failed = 0
for mi in mis
    time() - t0 > BUDGET && break
    r = try Base.code_typed_by_type(mi.specTypes; interp = C.NativeInterpreter(world; facts = true), optimize = true) catch; nothing end
    (r === nothing || length(r) != 1 || !(r[1][1] isa Core.CodeInfo)) && (global failed += 1; continue)
    src = r[1][1]; global done += 1
    caller = rootm(mi.def.module)
    for st in src.code
        st isa Expr && st.head === :(=) && (st = st.args[2])
        st isa Expr && st.head === :call || continue
        f = callee(src, st.args[1])
        (f isa Core.Builtin || f isa Core.IntrinsicFunction) && continue
        global sites += 1
        k = if f === nothing
            "the callee is not a constant (a called value)"
        else
            ft = Core.Typeof(f); om = f isa Type ? parentmodule(Base.unwrap_unionall(f) isa DataType ? Base.unwrap_unionall(f).name.module : Core) : parentmodule(f)
            name = f isa Type ? (Base.unwrap_unionall(f) isa DataType ? Base.unwrap_unionall(f).name.name : :Type) : nameof(f)
            own = rootm(om) in ROOTS
            pub = try Base.ispublic(om, name) catch; false end
            ms = try methods(f) catch; nothing end
            allown = ms !== nothing && all(m -> rootm(m.module) == rootm(om), ms)
            if own && !pub && allown
                at = Any[argtype(src, a) for a in st.args[2:end]]
                sig = try Tuple{ft, at...} catch; nothing end
                nm = sig === nothing ? -1 : (mm = Base._methods_by_ftype(sig, 4, world); mm === nothing ? 4 : length(mm))
                rt = try (sig === nothing ? Any : C.return_type(sig)) catch; Any end
                tk = nm == -1 ? "signature not formed" : nm > 3 ? "more than three methods match" : rt === Any ? "plain inference gives Any" : isconcretetype(rt) ? "plain inference gives a concrete type" : "plain inference gives an abstract type or a union"
                typed[tk] = get(typed, tk, 0) + 1
                fk = string(rootm(om), ".", name); ownfuns[fk] = get(ownfuns, fk, 0) + 1
                "own function, not public, every method the owner's"
            elseif own && !pub; "own function, not public, with another package's methods"
            elseif own; "own function, public or exported"
            elseif rootm(om) in (:Base, :Core); "Base's or Core's function"
            else; "another package's function"
            end
        end
        counts[k] = get(counts, k, 0) + 1
        ex = get!(examples, k, String[]); length(ex) < 6 && push!(ex, first(string(f, " in ", mi.def.name, " [", basename(string(mi.def.file)), ":", mi.def.line, "]"), 140))
    end
end
println("roots ", join(ROOTS, ","), " | own facts instances ", length(mis), ", inferred again ", done, " (failed ", failed, ") in ", round(time() - t0; digits = 1), " s | calls left to run time ", sites)
for (k, v) in sort(collect(counts); by = last, rev = true)
    println(lpad(v, 6), "  ", lpad(round(100v / max(sites, 1); digits = 1), 5), " %  ", k)
    for e in examples[k]; println("             ", e); end
end
println("the own, owner-only sites, by what plain inference of the call gives: ", join(["$k $v" for (k, v) in sort(collect(typed); by = last, rev = true)], "; "))
println("the own functions most called at such sites: ", join(["$k $v" for (k, v) in sort(collect(ownfuns); by = last, rev = true)[1:min(end, 25)]], ", "))
