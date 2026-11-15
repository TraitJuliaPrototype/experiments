# E-397 (W-152; the review of 2026-11-15, P2): the definition-time check against the method read at the box.
# For each method at a trait argument: `classify(m)` (the check: its uses outside the contract), against the
# method inferred by the facts rule at the signature with `Dynamic{X}` in each trait argument's place:
#   - a call left to run time that takes a value known by a trait or a box (a use the box cannot resolve);
#   - a call with such a value that can only throw (its inferred type is Union{}: no method for the box).
#     AGREE_ROOTS=TraitTables,TraitCSV julia --project=<env> agree.jl <package>...
using TraitWorld
for p in ARGS; Core.eval(Main, Meta.parse("using $p")); end
const C = Base.Compiler; const TW = TraitWorld
const ROOTS = Tuple(Symbol.(split(ENV["AGREE_ROOTS"], ",")))
world = Base.get_world_counter()
mods = Module[]
function allmods!(M)
    M in mods && return; push!(mods, M)
    for n in names(M; all = true)
        isdefined(M, n) || continue
        x = try getglobal(M, n) catch; continue end
        x isa Module && parentmodule(x) === M && x !== M && allmods!(x)
    end
end
for m in values(Base.loaded_modules); nameof(m) in ROOTS && allmods!(m); end
isdefined(Main, :EXTRA) && foreach(allmods!, Main.EXTRA)      # mistakes.jl's module
"the method's signature with a box in each trait argument's place; nothing where it cannot be formed"
function boxsig(m::Method)
    sig = m.sig; vars = TypeVar[]
    while sig isa UnionAll; push!(vars, sig.var); sig = sig.body; end
    ps = collect(sig.parameters)
    env = IdDict{Any,Any}()
    # a variable that types an argument and is bounded by a trait stands for the box
    for (i, p) in enumerate(ps)
        i == 1 && continue
        if p isa TypeVar && TW._trait_of(p.ub) !== nothing; env[p] = (:box, p.ub); end
    end
    sub(@nospecialize(t)) = begin
        for v in reverse(vars)       # innermost last
            t = t isa UnionAll || true ? t : t
        end
        t
    end
    # give each free variable a type: Float64 where its bound allows, else its bound
    vals = Any[]
    for v in vars
        ub = v.ub
        for (w, x) in zip(vars, vals); ub = ub isa Type || ub isa TypeVar ? _subst(ub, w, x) : ub; end
        val = haskey(env, v) ? nothing : (Float64 <: ub && v.lb === Union{} ? Float64 : (ub isa Type && isconcretetype(ub) ? ub : nothing))
        if haskey(env, v)
            X = ub; X isa UnionAll && (X = _close(X)); X === nothing && return nothing
            val = try Core.Dynamic{X} catch; return nothing end
        end
        val === nothing && return nothing
        push!(vals, val)
    end
    out = Any[]
    for (i, p) in enumerate(ps)
        for (w, x) in zip(vars, vals); p = _subst(p, w, x); end
        if i > 1 && !(p isa Core.TypeofVararg)
            X = TW._trait_of(p)
            if X !== nothing
                X isa UnionAll && (X = _close(X)); X === nothing && return nothing
                p = try Core.Dynamic{X} catch; return nothing end
            end
        end
        push!(out, p)
    end
    try Tuple{out...} catch; nothing end
end
_subst(@nospecialize(t), v::TypeVar, @nospecialize(x)) = t === v ? x : t isa Core.TypeofVararg ? t : (try (UnionAll(v, t)){x} catch; t end)
function _close(@nospecialize(X))      # a trait with open parameters: Float64 where the bound allows
    while X isa UnionAll
        Float64 <: X.var.ub || return nothing
        X = X{Float64}
    end
    X
end
istraitval(@nospecialize(T)) = T isa Type && (T <: Core.Dynamic || TW._trait_of(T) !== nothing)
argtype(src, @nospecialize(a)) =
    a isa Core.SSAValue ? C.widenconst(src.ssavaluetypes[a.id]) :
    a isa Core.Argument ? C.widenconst(src.slottypes[a.n]) :
    a isa Core.SlotNumber ? C.widenconst(src.slottypes[a.id]) :
    a isa GlobalRef ? (isdefined(a.mod, a.name) && isconst(a.mod, a.name) ? Core.Typeof(getglobal(a.mod, a.name)) : Any) :
    a isa QuoteNode ? Core.Typeof(a.value) : a isa Expr ? Any : Core.Typeof(a)
fname(src, @nospecialize(a)) = a isa GlobalRef ? string(a.name) : a isa Core.SSAValue ? string(src.ssavaluetypes[a.id]) : string(a)
function atbox(m::Method)
    sig = boxsig(m)
    sig === nothing && return nothing
    r = try Base.code_typed_by_type(sig; interp = C.NativeInterpreter(world; facts = true), optimize = true) catch; return nothing end
    (length(r) == 1 && r[1][1] isa Core.CodeInfo) || return nothing
    src = r[1][1]; faults = String[]
    for (i, st) in enumerate(src.code)
        st isa Expr && st.head === :(=) && (st = st.args[2])
        st isa Expr && st.head in (:call, :invoke) || continue
        args = st.head === :invoke ? st.args[2:end] : st.args
        f = args[1]
        fv = f isa GlobalRef ? (isdefined(f.mod, f.name) && isconst(f.mod, f.name) ? getglobal(f.mod, f.name) : nothing) :
             f isa QuoteNode ? f.value : (f isa Core.SSAValue || f isa Core.Argument || f isa Core.SlotNumber) ? nothing : f
        ats = Any[argtype(src, a) for a in args[2:end]]
        if fv === Core.throw_methoderror       # a call that found no method, as the optimizer leaves it
            any(istraitval, ats) && push!(faults, "no method: " * join(ats, ", "))
            continue
        end
        (fv isa Core.Builtin || fv isa Core.IntrinsicFunction) && continue
        any(istraitval, ats) || continue
        # an operation on a value known by its trait is declared: the split with its declared result (traits §7.9)
        if st.head === :call && fv !== nothing
            op = try C.declared_operation_result(C.NativeInterpreter(world; facts = true), Any[C.Const(fv), ats...], Tuple{Core.Typeof(fv), ats...}) catch; nothing end
            op === nothing || continue
        end
        if st.head === :call
            push!(faults, "left to run time: " * fname(src, f) * "(" * join(ats, ", ") * ")")
        elseif src.ssavaluetypes[i] === Union{}
            push!(faults, "only throws: " * fname(src, f) * "(" * join(ats, ", ") * ")")
        end
    end
    (; sig, faults, rt = r[1][2])
end
rows = Any[]; skipped = 0; nmeth = 0; seenm = IdSet{Any}()
for M in mods, name in names(M; all = true)
    isdefined(M, name) || continue
    f = try getglobal(M, name) catch; continue end
    (f isa Function || f isa Type) || continue
    for m in methods(f)
        m.module === M || continue
        TW._trait_arguments(m) || continue
        m in seenm && continue; push!(seenm, m)
        global nmeth += 1
        uses = try TW.classify(m) catch e; nothing end
        b = atbox(m)
        (uses === nothing || b === nothing) && (global skipped += 1; continue)
        push!(rows, (; m, uses, b, marked = TW._bounded_option(m) === false))
    end
end
println("roots ", join(ROOTS, ","), " | modules ", length(mods), " | methods at a trait argument ", nmeth, "; compared ", length(rows), " (not formed or failed ", skipped, ")")
cb(r) = isempty(r.uses); bb(r) = isempty(r.b.faults)
println("the check passes, the box is clean:  ", count(r -> cb(r) && bb(r), rows))
println("the check reports, the box has faults: ", count(r -> !cb(r) && !bb(r), rows))
println("the check passes, the box has faults:  ", count(r -> cb(r) && !bb(r), rows))
println("the check reports, the box is clean:   ", count(r -> !cb(r) && bb(r), rows), "   (marked @unbounded among all compared: ", count(r -> r.marked, rows), ")")
for (label, pred) in (("THE CHECK PASSES, THE BOX HAS FAULTS", r -> cb(r) && !bb(r)), ("THE CHECK REPORTS, THE BOX IS CLEAN", r -> !cb(r) && bb(r)), ("BOTH REPORT", r -> !cb(r) && !bb(r)))
    println("\n", label)
    for r in filter(pred, rows)[1:min(end, 40)]
        println("  ", r.m.module, ".", r.m.name, " [", basename(string(r.m.file)), ":", r.m.line, "]", r.marked ? "  @unbounded" : "", "   at ", first(string(r.b.sig), 110))
        for u in r.uses[1:min(end, 3)]; println("      check: ", first(string(u.what), 150)); end
        for x in r.b.faults[1:min(end, 3)]; println("      box:   ", first(x, 170)); end
    end
end
