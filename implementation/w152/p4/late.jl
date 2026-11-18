# E-394 (W-152; the review of 2026-11-15, P4): what methods for the required operations of Base's
# functions end in plain code, when they are added after plain work: as the library has them, at open
# sets (`length(::HasLength)`, `iterate(::Iterable)`, ...), against methods at the box type alone.
#     julia --project=../../w134/env_lib late.jl <csv> lib     the library loaded after the work (E-381's U-late), by method
#     julia --project=../../w134/env_lib late.jl <csv> box     no library: the same operations' methods at Core.Dynamic
const csv = ARGS[1]; const mode = ARGS[2]
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
before = valid()
inv = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
if mode == "lib"
    @eval using TraitWorld
else
    @eval begin
        const D = Core.Dynamic
        obj(d) = getfield(d, :object)
        Base.length(d::D) = length(obj(d))
        Base.iterate(d::D) = iterate(obj(d))
        Base.iterate(d::D, s) = iterate(obj(d), s)
        Base.getindex(d::D, i::Int) = getindex(obj(d), i)
        Base.getindex(d::D, k) = getindex(obj(d), k)
        Base.firstindex(d::D) = firstindex(obj(d))
        Base.setindex!(d::D, x, i::Int) = setindex!(obj(d), x, i)
        Base.push!(d::D, x) = push!(obj(d), x)
        Base.resize!(d::D, n::Int) = resize!(obj(d), n)
        Base.haskey(d::D, k) = haskey(obj(d), k)
        Base.get(d::D, k, default) = get(obj(d), k, default)
    end
end
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
lost = [ci for ci in before if ci.max_world != typemax(UInt)]
by = Dict{Symbol,Int}()
for ci in lost; d = ci.def.def; k = d isa Method ? nameof(Base.moduleroot(d.module)) : :toplevel; by[k] = get(by, k, 0) + 1; end
println("mode ", mode, ": plain instances ended ", length(lost), " of ", length(before), " | ", join(["$k $n" for (k, n) in sort(collect(by); by = last, rev = true)], ", "))
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
