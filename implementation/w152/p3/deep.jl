# E-395 (W-152; the review of 2026-11-15, P3): deep G2 on E-392's session.
# An instance is deep G2 when it has the G2 bit and every CodeInstance among its edges, transitively, has it.
# An instance with no edge at all counts as having the bit: it rests on nothing (the edge instances made for
# constant-propagated results of builtins carry no bit and no edge).
#     julia --project=../../w134/env_forks|env_facts deep.jl <csv> <out.jls> <package>...
# (a) the own image instances by class, and those the loads end, by class;
# (b) the callees outside the own modules that are not deep G2, below the own facts instances: the culprits
#     (no G2 bit themselves) and the cone above them; written to <out.jls> for the inference of (c).
using Serialization
const csv, outf = ARGS[1], ARGS[2]; const pk = ARGS[3:end]
const G2, FACTS = 0x10, 0x20
const CORE8 = (:CSV, :DataFrames, :Tables, :Parsers, :InlineStrings, :PooledArrays, :WeakRefStrings, :SentinelArrays)
@eval using CSV, DataFrames
w = @eval () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                 g = combine(groupby(df, names(df)[end]), c => sum); string(hash(repr((d, first(s, 3), g))); base = 16))
rootof(ci::Core.CodeInstance) = (d = ci.def; d isa Core.MethodInstance && d.def isa Method ? nameof(Base.moduleroot(d.def.module)) : :none)
valid(ci) = ci.max_world == typemax(UInt)
function tally()
    out = Core.CodeInstance[]
    Base.visit(Core.methodtable) do m
        nameof(Base.moduleroot(m.module)) in CORE8 || return
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance && isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                valid(ci) && ci.owner === nothing && push!(out, ci)
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    out
end
rawbit(ci) = (ci.flags & G2) != 0
# without the bit, but resting on nothing or on bindings alone (G2 allows a binding edge)
onlybindings(ci) = all(x -> x isa Core.Binding, ci.edges)
bit(ci) = rawbit(ci) || onlybindings(ci)
callees(ci::Core.CodeInstance) = (e = ci.edges; Core.CodeInstance[x for x in e if x isa Core.CodeInstance])
# the class: not deep where the bit is missing here or at an instance reached through edges
const notdeep = IdDict{Any,Bool}(); const kinds = Dict{String,Int}()
function classify!(roots)
    seen = IdSet{Any}(); stack = Any[roots...]; rev = IdDict{Any,Vector{Any}}()
    while !isempty(stack)
        ci = pop!(stack); ci in seen && continue; push!(seen, ci)
        for x in ci.edges; k = string(typeof(x).name.name); kinds[k] = get(kinds, k, 0) + 1; end
        for c in callees(ci); push!(get!(rev, c, Any[]), ci); c in seen || push!(stack, c); end
    end
    work = Any[ci for ci in seen if !bit(ci)]
    for ci in work; notdeep[ci] = true; end
    while !isempty(work)
        c = pop!(work)
        for p in get(rev, c, Any[]); haskey(notdeep, p) || (notdeep[p] = true; push!(work, p)); end
    end
    seen
end
deep(ci) = !haskey(notdeep, ci)
image = tally()
d1 = Base.invokelatest(w); Base.invokelatest(w)
seen0 = IdSet{Any}(image); made = [ci for ci in tally() if !(ci in seen0)]
own = vcat(image, made)
reach = classify!(own)
println("project ", basename(dirname(Base.active_project())), " | own instances: image ", length(image), ", made by the work ", length(made), " | reached through edges ", length(reach))
println("edge entries by kind: ", join(["$k $v" for (k, v) in sort(collect(kinds); by = last, rev = true)], ", "))
cls(set) = (n = length(set); f = count(ci -> (ci.flags & FACTS) != 0, set); g = count(bit, set); dd = count(deep, set); "$n (facts $f, G2 bit $g, deep G2 $dd)")
println("image: ", cls(image)); println("made:  ", cls(made))
# the instances outside the own modules below the own facts instances
factsown = [ci for ci in own if (ci.flags & FACTS) != 0]
below = IdSet{Any}(); st = Any[factsown...]; vis = IdSet{Any}()
while !isempty(st); ci = pop!(st); ci in vis && continue; push!(vis, ci); for c in callees(ci); push!(st, c); rootof(c) in CORE8 || push!(below, c); end; end
nd = [ci for ci in below if !deep(ci)]; culprits = [ci for ci in nd if !bit(ci)]
println("below the own facts instances, outside the own modules: ", length(below), " instances; not deep G2 ", length(nd), "; of them without the bit themselves (culprits) ", length(culprits))
byroot(set) = (b = Dict{Symbol,Int}(); for ci in set; b[rootof(ci)] = get(b, rootof(ci), 0) + 1; end; join(["$k $v" for (k, v) in sort(collect(b); by = last, rev = true)], ", "))
ek = Dict{String,Int}(); for ci in below; rawbit(ci) && continue; k = join(sort(unique(string(typeof(x).name.name) for x in ci.edges)), "+"); k = isempty(k) ? "(no edge)" : k; ek[k] = get(ek, k, 0) + 1; end
println("  below, without the flag's bit, by the kinds of their edges: ", join(["$k $v" for (k, v) in sort(collect(ek); by = last, rev = true)], ", "))
println("  not deep by root: ", byroot(nd)); println("  culprits by root: ", byroot(culprits))
bym = Dict{String,Int}(); for ci in culprits; m = ci.def.def; k = string(m.module, ".", m.name); bym[k] = get(bym, k, 0) + 1; end
println("  culprits by method name (", length(bym), " names): ", join(["$k $v" for (k, v) in sort(collect(bym); by = last, rev = true)[1:min(end, 40)]], ", "))
# own facts instances that are not deep: directly by a callee outside
ownnd = [ci for ci in factsown if !deep(ci)]
println("own facts instances not deep G2: ", length(ownnd), " of ", length(factsown), " | with the G2 bit ", count(bit, ownnd))
# how far below is the nearest culprit, and how many culprits does one own instance rest on
function cone(ci)
    v = IdSet{Any}(); st = Any[ci]; c = IdSet{Any}()
    while !isempty(st); x = pop!(st); x in v && continue; push!(v, x); bit(x) || push!(c, x); for y in callees(x); deep(y) || push!(st, y); end; end
    c
end
allc = IdDict{Any,Int}(); sizes = Int[]
for ci in ownnd; c = cone(ci); push!(sizes, length(c)); for x in c; allc[x] = get(allc, x, 0) + 1; end; end
sort!(sizes); println("culprits under one own facts instance that is not deep: median ", sizes[max(1, end ÷ 2)], ", least ", first(sizes), ", most ", last(sizes))
top = sort(collect(allc); by = last, rev = true)[1:min(end, 25)]
println("the culprits most own facts instances rest on:")
for (x, n) in top; println("   ", lpad(n, 5), "  ", first(string(x.def.specTypes), 170)); end
serialize(outf, (; nd = [(ci.def.specTypes, ci.rettype, bit(ci)) for ci in nd],
                   direct = unique([c.def.specTypes for ci in factsown for c in callees(ci) if !(rootof(c) in CORE8) && !deep(c)])))
# the loads
tl = @elapsed for p in pk; Core.eval(Main, Meta.parse("using $p")); end
lost(set) = [ci for ci in set if !valid(ci)]
for (name, set) in (("image", image), ("made", made))
    l = lost(set); println(name, ": the loads end ", length(l), " of ", length(set), " | facts ", count(ci -> (ci.flags & FACTS) != 0, l), " | deep G2 among them ", count(deep, l), " | with the G2 bit ", count(bit, l))
    for ci in l; deep(ci) && println("   DEEP AND ENDED: ", ci.def.specTypes); end
end
println("of the below-instances not deep, ended by the loads: ", count(!valid, nd), " of ", length(nd), "; of the deep ones below: ", count(ci -> deep(ci) && !valid(ci), collect(below)), " of ", count(deep, collect(below)))
d2 = Base.invokelatest(w); println("digest ", d1, d1 == d2 ? " (equal after)" : " DIFFERS")
# a refinement to weigh: a callee whose result is Union{} (it only throws) taken as a run-time site by a
# facts caller: no edge to it, and no type lost. The own instances that are deep G2 then:
let nd2 = IdDict{Any,Bool}(), rev = IdDict{Any,Vector{Any}}(), seen = IdSet{Any}(), stack = Any[own...]
    kept(c) = c.rettype !== Union{}
    while !isempty(stack)
        ci = pop!(stack); ci in seen && continue; push!(seen, ci)
        for c in callees(ci); kept(c) || continue; push!(get!(rev, c, Any[]), ci); c in seen || push!(stack, c); end
    end
    work = Any[ci for ci in seen if !bit(ci)]; for ci in work; nd2[ci] = true; end
    while !isempty(work); c = pop!(work); for p in get(rev, c, Any[]); haskey(nd2, p) || (nd2[p] = true; push!(work, p)); end; end
    d2(ci) = !haskey(nd2, ci)
    println("with calls that only throw taken as run-time sites: own image instances deep G2 ", count(d2, image), " of ", length(image), "; own facts instances not deep ", count(!d2, factsown), " of ", length(factsown),
            "; ended by the loads and deep ", count(ci -> d2(ci) && !valid(ci), own))
    for ci in own; d2(ci) && !valid(ci) && println("   deep under the refinement and ended: ", first(string(ci.def.specTypes), 200)); end
end
