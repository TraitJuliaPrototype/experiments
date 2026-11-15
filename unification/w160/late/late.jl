# E-404 (W-151): `w152/p4/late.jl` (E-394) again: what a late load ends in plain code, after upstream CSV's and
# DataFrames' work compiled plainly. Two loads in turn, each measured by itself: the library (`using TraitWorld`: the
# wrapper's methods, `convert` into `Dynamic{X}`, the wrapper's family in every trait at the head), then the ODE port
# (`using TraitDifferentialEquations`: the forwarders of `@erasing` at the head). env_head: the heads; env_base: the tag.
#     julia --project=env_<head|base> late.jl <csv>
const csv = ARGS[1]
using Statistics
@eval using CSV, DataFrames
w = @eval () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                 g = combine(groupby(df, names(df)[end]), c => sum); nothing)
Base.invokelatest(w); Base.invokelatest(w)
valid() = (s = IdSet{Any}(); Base.visit(Core.methodtable) do meth
        for mi in Base.specializations(meth)
            mi isa Core.MethodInstance || continue
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci !== nothing
                ci.owner === nothing && ci.max_world == typemax(UInt) && push!(s, ci)
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end; s)
function measure(label, ex)
    before = valid()
    inv = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
    Core.eval(Main, ex)
    ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
    lost = [ci for ci in before if ci.max_world != typemax(UInt)]
    by = Dict{Symbol,Int}()
    for ci in lost; d = ci.def.def; k = d isa Method ? nameof(Base.moduleroot(d.module)) : :toplevel; by[k] = get(by, k, 0) + 1; end
    println("== ", label, ": plain instances ended ", length(lost), " of ", length(before), " | ", join(["$k $n" for (k, n) in sort(collect(by); by = last, rev = true)], ", "))
    println("log entries ", length(inv), "; tags: ", join(unique(string(x) for x in inv if x isa String), ", "))
    # the log by the definition that closes each group
    lostset = IdSet{Any}(lost); seen = IdSet{Any}(); group = Any[]; rows = Any[]
    for i in eachindex(inv)
        x = inv[i]
        if x isa Method && i < length(inv) && inv[i+1] isa String
            own = Any[]
            for g in group
                cis = g isa Core.CodeInstance ? Any[g] : Any[]
                if g isa Core.MethodInstance && isdefined(g, :cache)
                    ci = g.cache
                    while true; push!(cis, ci); isdefined(ci, :next) || break; ci = ci.next; end
                end
                for ci in cis; ci in lostset && !(ci in seen) && !(ci in own) && push!(own, ci); end
            end
            foreach(g -> push!(seen, g), own)
            isempty(group) || push!(rows, (length(own), length(group), string(nameof(x.module), ".", x.name), string(x.sig), inv[i+1]))
            empty!(group)
        elseif x isa Core.CodeInstance || x isa Core.MethodInstance
            push!(group, x)
        end
    end
    println("unclosed tail: ", length(group), " entries; kinds in the log: ", join(unique(string(typeof(x)) for x in inv), ", "))
    for (n, e, name, sig, tag) in sort(rows; by = first, rev = true)[1:min(end, 25)]
        println(lpad(n, 5), " plain instances, ", lpad(e, 5), " entries: ", name, "  ", first(sig, 150), "  [", tag, "]")
    end
    println("attributed to a closing method: ", sum(first, rows; init = 0), " of ", length(lost))
    # W-160 (E-439, E-444): the instances at a box (the check's and a box's call's) that ended, and the methods
    # the walk took on its conservative path
    atbox(ci) = occursin("Dynamic{", string(ci.def.specTypes))
    println("instances at a box: ", count(atbox, before), " valid before, ", count(atbox, lost), " ended, ",
            count(atbox, valid()), " valid after the load; jl_method_table_disable entries: ",
            count(==("jl_method_table_disable"), inv))

end
measure("the library (using TraitWorld)", :(using TraitWorld))
measure("the ODE port (using TraitDifferentialEquations)", :(using TraitDifferentialEquations))
