# diagnosis: the compiler's own MethodInstances invalidated by loading upstream CSV and DataFrames
inv = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
using CSV, DataFrames
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
mis = [x for x in inv if x isa Core.MethodInstance]
iscomp(mi) = mi.def isa Method && (mi.def.module === Base.Compiler || parentmodule(mi.def.module) === Base.Compiler)
println(Base.GIT_VERSION_INFO.commit_short, ": invalidated ", length(mis), ", of the compiler ", count(iscomp, mis))
# depth-1 entries (direct callers of an edge a new method changed), the compiler's
d1 = Dict{String,Int}()
for i in 1:length(inv)-1
    x = inv[i]
    if x isa Core.MethodInstance && inv[i+1] isa Int32 && inv[i+1] == 1 && iscomp(x)
        k = string(x.def.name); d1[k] = get(d1, k, 0) + 1
    end
end
println("  compiler instances at depth 1: ", join(["$k ($v)" for (k, v) in sort(collect(d1), by = x -> -x[2])[1:min(end, 12)]], ", "))
