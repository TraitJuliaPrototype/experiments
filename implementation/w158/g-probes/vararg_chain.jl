# Traits T-159: the walk below a call that only throws, for a closure over a vararg of boxes. Each level the walk
# reads: the callee's signature, and in its optimized code the calls that only throw, or that raise MethodError,
# with their argument types. Run from the library's worktree: $JN --project=. $W158/g-probes/vararg_chain.jl
using TraitWorld
const CC = TraitWorld.CC
println("TraitWorld at ", pathof(TraitWorld))
module V
using TraitWorld
@trait_module bounded = false
@trait CTab begin
    cn(t::CTab)::Int
end
call(ts::CTab...) = sum(t -> sum(t), ts)
c2(ts::Vararg{CTab, 2}) = sum(t -> sum(t), ts)
c1(t::CTab) = sum(t)
end

function walk(interp, @nospecialize(tt), depth, seen; maxdepth = 60)
    depth > maxdepth && (println("  "^min(depth, 30), "… depth ", depth); return)
    tt in seen && (println("  "^min(depth, 30), "(seen) ", tt); return)
    push!(seen, tt)
    r = try Base.code_typed_by_type(tt; interp, optimize = true) catch e; println("  error ", e); return end
    if !(length(r) == 1 && r[1][1] isa Core.CodeInfo)
        println("  "^min(depth, 30), depth, ": ", length(r), " results for ", tt); return
    end
    src = r[1][1]
    println("  "^min(depth, 30), depth, ": ", TraitWorld._callform(tt), " -> ", r[1][2])
    for (i, st) in enumerate(src.code)
        st isa Expr && st.head === :(=) && (st = st.args[2])
        st isa Expr && st.head in (:call, :invoke) || continue
        args = st.head === :invoke ? st.args[2:end] : st.args
        fv = TraitWorld._callee_value(src, args[1])
        ats = Any[TraitWorld._argtype(src, a) for a in args[2:end]]
        box = any(TraitWorld._at_box_value, ats)
        if fv === Core.throw_methoderror
            println("  "^min(depth, 30), "   %", i, " throw_methoderror at ", ats, box ? " (a value at the box)" : "")
        elseif src.ssavaluetypes[i] === Union{} && !(fv isa Core.Builtin)
            println("  "^min(depth, 30), "   %", i, " only throws: ", st.head, " ", fv, " at ", ats, box ? " (a value at the box)" : " (no value at the box: the walk stops here)")
            box && walk(interp, Tuple{TraitWorld._argtype(src, args[1]), ats...}, depth + 1, seen; maxdepth)
        end
    end
end
w = Base.get_world_counter()
for f in (V.c1, V.c2, V.call)
    m = only(methods(f))
    sig = TraitWorld.box_signature(m)
    println("\n== ", m.name, " at ", sig)
    fs = TraitWorld.check_at_box(m)
    foreach(u -> println("   fault: ", TraitWorld._fault_line(u)), fs)
    interp = CC.NativeInterpreter(w; facts = true)
    walk(interp, sig, 0, Set{Any}())
end
