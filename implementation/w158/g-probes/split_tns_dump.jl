# The keyword body of P.vB (split_tns.jl) at the box, whole; the method lookup at the call's types.
include(joinpath(@__DIR__, "split_tns.jl"))
kb = only(m for m in methods(getglobal(P, only(n for n in names(P; all = true) if startswith(string(n), "#vB#")))))
sig = TraitWorld.box_signature(kb)
println("\n#### the keyword body at ", sig)
src = TraitWorld._box_instance(sig, Base.get_world_counter())
println("cached instance: ", src !== nothing)
interp = TraitWorld.CC.NativeInterpreter(Base.get_world_counter(); facts = true)      # as check_at_box reads it
src === nothing && (src = Base.code_typed_by_type(sig; interp, optimize = true)[1][1])
for (i, st) in enumerate(src.code)
    println("  %", i, " = ", st, " :: ", src.ssavaluetypes[i])
end
for (i, st) in enumerate(src.code)
    st isa Expr && st.head === :call || continue
    occursin("solve_nonlinear", string(st)) || continue
    ats = Any[TraitWorld._argtype(src, a) for a in st.args]
    tt = Tuple{ats...}
    println("lookup at ", tt, ": ", Base._methods_by_ftype(tt, -1, Base.get_world_counter()))
end
