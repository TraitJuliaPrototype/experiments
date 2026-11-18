# W-155b: an owner-only call left to run time with few matching methods: its argument types and info.
for p in ARGS[2:end]; Core.eval(Main, Meta.parse("using $p")); end
const C = Base.Compiler
fname = Symbol(ARGS[1])
world = Base.get_world_counter(); interp = C.NativeInterpreter(world; facts = true)
n = 0
Base.visit(Core.methodtable) do m
    global n
    n >= 4 && return
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance && isdefined(mi, :cache) || continue
        (mi.cache.flags & 0x20) != 0 || continue
        r = try Base.code_ircode_by_type(mi.specTypes; interp) catch; nothing end
        (r === nothing || length(r) != 1 || !(r[1][1] isa C.IRCode)) && continue
        ir = r[1][1]
        for i in 1:length(ir.stmts)
            st = ir.stmts.stmt[i]
            st isa Expr && st.head === :call || continue
            a = st.args[1]
            (a isa GlobalRef && a.name === fname) || continue
            info = ir.stmts.info[i]
            at = Any[a isa Core.SSAValue ? ir.stmts.type[a.id] : a isa Core.Argument ? ir.argtypes[a.n] : Core.Typeof(a) for a in st.args[2:end]]
            println(mi.def.name, " | ", typeof(info), " | args ", at)
            n += 1; n >= 4 && return
        end
    end
end
