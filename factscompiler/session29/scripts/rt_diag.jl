using TraitWorld
include("/home/hellmann/Repos/julia-trait-bound/experiments/factscompiler/recovery/RTTrait.jl")
using .RTTrait
RTTrait.perf_raytrace(3, 8, 2)
t = @elapsed RTTrait.perf_raytrace(5, 64, 2); a = @allocated RTTrait.perf_raytrace(5, 64, 2)
println("trait raytrace (5, 64, 2): ", round(1000t; digits = 1), " ms, ", a, " bytes")
println("candidates: ", Base.Compiler.dynamic_candidates(TraitWorld._family(RTTrait.Scene)))
# the Group worker's facts code: splits, dynamic calls
fi = Base.Compiler.NativeInterpreter(Base.get_world_counter(); facts = true, owner = :facts)
for m in methods(RTTrait.intersect)
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        occursin("Group", string(mi.specTypes)) || continue
        src = only(Base.code_typed_by_type(mi.specTypes; interp = fi))[1]
        n_isa = count(st -> st isa Expr && st.head === :call && string(st.args[1]) == "isa", src.code)
        n_call = count(st -> st isa Expr && st.head === :call && !(st.args[1] isa GlobalRef && st.args[1].mod === Core), src.code)
        n_inv = count(st -> st isa Expr && st.head === :invoke, src.code)
        println(mi.specTypes, "\n   isa ", n_isa, ", invokes ", n_inv, ", calls ", n_call)
        for st in src.code; st isa Expr && st.head in (:call, :invoke) && occursin("intersect", string(st)) && println("     ", first(string(st), 180)); end
    end
end
