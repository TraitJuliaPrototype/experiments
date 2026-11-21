# Traits T-159: Base's mapfoldl_impl at a tuple of boxes of no fixed length, as the walk reads it (facts), whole.
# Run from the library's worktree: $JN --project=. $W158/g-probes/vararg_mapfoldl.jl
include(joinpath(@__DIR__, "vararg_chain.jl"))
src0 = Base.code_typed_by_type(TraitWorld.box_signature(only(methods(V.call))); interp = CC.NativeInterpreter(w; facts = true), optimize = true)[1][1]
CL = TraitWorld._argtype(src0, src0.code[1].args[2])
for (label, T) in (("no fixed length", Tuple{Dynamic{V.CTab}, Vararg{Dynamic{V.CTab}}}), ("one box", Tuple{Dynamic{V.CTab}}))
    for facts in (true, false)
        tt = Tuple{typeof(Base.mapfoldl_impl), CL, typeof(Base.add_sum), Base._InitialValue, T}
        r = Base.code_typed_by_type(tt; interp = CC.NativeInterpreter(w; facts), optimize = true)
        println("\n#### mapfoldl_impl at a tuple of ", label, ", facts = ", facts, ": ", r[1][2])
        for (i, st) in enumerate(r[1][1].code)
            println("   %", i, " = ", st, " :: ", r[1][1].ssavaluetypes[i])
        end
    end
end
