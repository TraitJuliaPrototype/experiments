# W-143d (E-540): the culprits with a fault in the census's group "a type's field read by getproperty at a kind":
# the method, the fault's signature, the cones it is in.     run.sh <label> <session> diag/kindprop.jl
include(joinpath(@__DIR__, "..", "census_lib.jl"))
const csv = ARGS[1]
S = census_session(csv)
iskindarg(@nospecialize(t)) = iskind(t) || t === Core.TypeofVararg
rows = Tuple{Int,String,String}[]
for (y, k) in S.culprit
    for f in get(S.fcache, y, Fault[])
        f.kind === :mi && continue
        n = fnname(fname(f.sig)); (n === :getproperty || n === :setproperty!) || continue
        a = args(f.sig); (!isempty(a) && iskindarg(a[1])) || continue
        push!(rows, (get(S.incone, y, 0), first(string(y.def.specTypes), 150), first(string(f.sig), 110)))
    end
end
for r in sort(rows; rev = true); println(lpad(r[1], 5), "  ", r[2], "\n        ", r[3]); end
