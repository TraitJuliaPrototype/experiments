# C-157, diagnosis of the `all` form: the call info inference gives `f(t)` in `_all` (f the closure, t typed
# Callable{Tuple{Float64}, Bool}), against the same at an element typed `Function` (plain Julia's control).
const Callable = Core.Callable
mk(x) = t -> t(x)
cl = mk(2.0)
for V in (Vector{Callable{Tuple{Float64}, Bool}}, Vector{Function})
    ir, rt = only(Base.code_ircode(Base._all, (typeof(cl), V, Colon); optimize_until = "CC: SLOT2REG"))
    println("== ", V, " => ", rt)
    for i in 1:length(ir.stmts)
        st = ir.stmts[i][:stmt]
        if Meta.isexpr(st, :call) && (st.args[1] isa Core.Argument && st.args[1].n == 2)
            println("  stmt ", i, ": ", st, " :: ", ir.stmts[i][:type], "  info ", typeof(ir.stmts[i][:info]))
            inf = ir.stmts[i][:info]
            if hasproperty(inf, :call); println("     .call ", typeof(inf.call)); end
            for fn in fieldnames(typeof(inf)); println("     .", fn, " = ", typeof(getfield(inf, fn))); end
        end
    end
    ci, _ = only(Base.code_typed(Base._all, (typeof(cl), V, Colon)))
    for (i, st) in enumerate(ci.code)
        (Meta.isexpr(st, :call) || Meta.isexpr(st, :invoke)) && occursin("_2", string(st)) && !occursin("getfield", string(st)) && println("  optimized ", i, ": ", st, " :: ", ci.ssavaluetypes[i])
    end
end
# the closure's instance at the member's own type, and at the set
for T in (Callable{Tuple{Float64}, Bool}, typeof(x -> 1))
    ci, rt = only(Base.code_typed(cl, (T,)))
    println("== closure at ", T, " => ", rt, "; typeassert ", any(s -> Meta.isexpr(s, :call) && s.args[1] == GlobalRef(Core, :typeassert), ci.code))
end
