using TraitWorld
include("/home/hellmann/Repos/julia-trait-bound/experiments/factscompiler/recovery/RTTrait.jl")
using .RTTrait
RTTrait.perf_raytrace(3, 8, 2)
cands = Base.Compiler.dynamic_candidates(TraitWorld._family(RTTrait.Scene))
println("candidates: ", cands)
fi = Base.Compiler.NativeInterpreter(Base.get_world_counter(); facts = true, owner = :facts)
for C in cands
    occursin("Group", string(C)) || continue
    sig = Tuple{typeof(RTTrait.intersect), C, RTTrait.Hit, RTTrait.Ray}
    for (src, rt) in Base.code_typed_by_type(sig; interp = fi)
        println(sig, " => ", rt); println(src)
    end
end
