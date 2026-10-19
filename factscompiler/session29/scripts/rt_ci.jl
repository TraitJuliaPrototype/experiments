using TraitWorld
include("/home/hellmann/Repos/julia-trait-bound/experiments/factscompiler/recovery/RTTrait.jl")
using .RTTrait
RTTrait.perf_raytrace(3, 8, 2)
function show_cis(f, pat)
    for m in methods(f), mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        occursin(pat, string(mi.specTypes)) || continue
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            println("== ", mi.specTypes, " owner=", repr(ci.owner), " rettype=", ci.rettype, " inferred=", typeof(ci.inferred), " invoke? ", ci.invoke != C_NULL)
            if ci.inferred isa String || ci.inferred isa Vector{UInt8}
                src = Base._uncompressed_ir(ci, ci.inferred)
                for (i, st) in enumerate(src.code)
                    st isa Expr && st.head in (:call, :invoke, :foreigncall) && println("   ", i, ": ", first(string(st), 200), " :: ", src.ssavaluetypes[i])
                end
            end
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
end
println("##### TObj/Dynamic intersect"); show_cis(RTTrait.intersect, "Group")
println("##### opcall"); show_cis(TraitWorld.opcall, "Group")
println("##### _dispatch"); show_cis(TraitWorld._dispatch, "Group")
println("##### Dynamic op"); show_cis(RTTrait.intersect, "Dynamic")
