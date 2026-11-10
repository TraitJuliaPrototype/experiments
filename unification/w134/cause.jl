# E-355, the follow-up: which new method ends which of the packages' image instances? The invalidation
# log of the nine loads, grouped by the method that closes each group of entries.
#     julia --project=env_* cause.jl <package>...
# CAUSE_WORK=<csv>: E-355's work runs before the loads, so the instances it made are in the session (E-356).
# CAUSE_ROOTS=A,B,...: the root modules whose instances are reported, in place of the eight.
const FACTS = 0x20
const CORE8 = haskey(ENV, "CAUSE_ROOTS") ? Tuple(Symbol.(split(ENV["CAUSE_ROOTS"], ","))) :
    (:CSV, :DataFrames, :Tables, :Parsers, :InlineStrings, :PooledArrays, :WeakRefStrings, :SentinelArrays)
using CSV, DataFrames
if haskey(ENV, "CAUSE_WORK")
    let csv = ENV["CAUSE_WORK"]
        df = CSV.read(csv, DataFrame); describe(df); c = names(df)[1]; sort(df, c); combine(groupby(df, names(df)[end]), c => sum)
    end
end
inv = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
for p in ARGS; Core.eval(Main, Meta.parse("using $p")); end
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
root(x) = x isa Core.CodeInstance ? root(x.def) : x isa Core.MethodInstance && x.def isa Method ? nameof(Base.moduleroot(x.def.module)) : :none
facts(x) = x isa Core.CodeInstance && (x.flags & FACTS) != 0
println(length(inv), " log entries; tags: ", join(unique(string(x) for x in inv if x isa String), ", "))
group = Any[]; depths = Any[]
for i in eachindex(inv)
    x = inv[i]
    if x isa Method && i < length(inv) && inv[i+1] isa String
        own = [(g, d) for (g, d) in zip(group, depths) if root(g) in CORE8]
        if !isempty(own)
            nf = count(t -> facts(t[1]), own)
            println("\n", inv[i+1], ": ", x.module, ".", x.name, " ", x.sig, "\n   ends ", length(group), " entries; of the eight ", length(own), " (facts ", nf, ")")
            for (g, d) in own[1:min(end, 6)]
                println("     depth ", d, facts(g) ? " facts " : " plain ", g isa Core.CodeInstance ? g.def.specTypes : g.specTypes)
            end
            # the entries just before the first own one: the path to it
            k = findfirst(g -> root(g) in CORE8, group)
            for j in max(1, k - 4):k-1
                g = group[j]; println("     before: depth ", depths[j], facts(g) ? " facts " : " plain ", root(g), " ", g isa Core.CodeInstance ? g.def.specTypes : g.specTypes)
            end
        end
        empty!(group); empty!(depths)
    elseif x isa Core.CodeInstance || x isa Core.MethodInstance
        push!(group, x); push!(depths, i < length(inv) ? inv[i+1] : nothing)
    end
end
own = [g for g in group if root(g) in CORE8]
println("\nunclosed tail: ", length(group), " entries, of the eight ", length(own))
