# W-155 (D-5, D-6; E-416 to E-418): the deep class of G2 on E-392's session, read from the build and by a walk.
# W-152's tool (`../w152/p3/deep.jl`, E-395) extended: the bit as the build sets it, against the class a walk
# over the edges gives; the edges that name a callee without its CodeInstance; the calls that only throw.
#     julia --project=env_forks|env_facts deep.jl <csv> <package>...
# An instance's class, three ways:
#   bit   the G2 bit as the build sets it (`flags & 0x10`);
#   walk  the bit here and on every CodeInstance among its edges, transitively (the bit as built, no correction);
#   corr  the same walk with E-395's correction: an instance whose edges are bindings only counts as having the bit.
# The throw-only refinements of the walk (E-395's last line): an edge to a callee whose result is `Union{}` is
# not followed, (a) from code compiled by facts only (D-6 as the rule states it), (b) from any code (E-395's).
using Serialization
const csv = ARGS[1]; const pk = ARGS[2:end]
const G2, FACTS = 0x10, 0x20
const CORE8 = (:CSV, :DataFrames, :Tables, :Parsers, :InlineStrings, :PooledArrays, :WeakRefStrings, :SentinelArrays)
@eval using CSV, DataFrames
w = @eval () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                 g = combine(groupby(df, names(df)[end]), c => sum); string(hash(repr((d, first(s, 3), g))); base = 16))
rootof(ci::Core.CodeInstance) = (d = ci.def; d isa Core.MethodInstance && d.def isa Method ? nameof(Base.moduleroot(d.def.module)) : :none)
valid(ci) = ci.max_world == typemax(UInt)
isfacts(ci) = (ci.flags & FACTS) != 0
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
corrbit(ci) = rawbit(ci) || all(x -> x isa Core.Binding, ci.edges)
callees(ci::Core.CodeInstance) = Core.CodeInstance[x for x in ci.edges if x isa Core.CodeInstance]
# the class by a walk: not deep where `bit` fails here or at an instance reached through CodeInstance edges;
# `follow(caller, callee)` says whether an edge counts
function classify(roots, bit, follow)
    seen = IdSet{Any}(); stack = Any[roots...]; rev = IdDict{Any,Vector{Any}}()
    while !isempty(stack)
        ci = pop!(stack); ci in seen && continue; push!(seen, ci)
        for c in callees(ci)
            follow(ci, c) || continue
            push!(get!(rev, c, Any[]), ci); c in seen || push!(stack, c)
        end
    end
    nd = IdDict{Any,Bool}(); work = Any[ci for ci in seen if !bit(ci)]
    for ci in work; nd[ci] = true; end
    while !isempty(work)
        c = pop!(work)
        for p in get(rev, c, Any[]); haskey(nd, p) || (nd[p] = true; push!(work, p)); end
    end
    return seen, ci -> !haskey(nd, ci)
end
throwonly(c) = c.rettype === Union{}
image = tally()
d1 = Base.invokelatest(w); Base.invokelatest(w)
seen0 = IdSet{Any}(image); made = [ci for ci in tally() if !(ci in seen0)]
own = vcat(image, made); factsown = filter(isfacts, own)
reach, dwalk = classify(own, rawbit, (_, _) -> true)
_, dcorr = classify(own, corrbit, (_, _) -> true)
_, dthrowf = classify(own, rawbit, (p, c) -> !(isfacts(p) && throwonly(c)))
_, dthrowa = classify(own, rawbit, (p, c) -> !throwonly(c))
_, dthrowa_c = classify(own, corrbit, (p, c) -> !throwonly(c))
_, dthrowf_c = classify(own, corrbit, (p, c) -> !(isfacts(p) && throwonly(c)))
println("project ", basename(dirname(Base.active_project())), " | julia ", Base.GIT_VERSION_INFO.commit_short,
        " | own instances: image ", length(image), ", made by the work ", length(made), " | reached through edges ", length(reach))
pc(n, d) = string(n, " (", round(Int, 100n / d), " %)")
for (name, set) in (("image", image), ("made", made), ("own facts", factsown))
    n = length(set)
    println(rpad(name * ":", 11), n, " | facts ", count(isfacts, set), " | bit ", count(rawbit, set),
            " | deep: walk ", pc(count(dwalk, set), n), ", corrected ", pc(count(dcorr, set), n),
            " | throw-only refinement: facts callers ", pc(count(dthrowf, set), n), ", every caller ", pc(count(dthrowa, set), n),
            "; corrected: facts callers ", pc(count(dthrowf_c, set), n), ", every caller ", pc(count(dthrowa_c, set), n))
end
# D-5's gate: the bit is the deep class
mism = [ci for ci in reach if rawbit(ci) != dwalk(ci)]
println("reached instances where the bit and the walk disagree: ", length(mism), " (bit without walk ", count(rawbit, mism), ")")
for ci in mism[1:min(end, 10)]; println("   ", rawbit(ci) ? "bit, walk not deep: " : "walk deep, no bit: ", first(string(ci.def.specTypes), 160)); end
binonly = [ci for ci in reach if !rawbit(ci) && all(x -> x isa Core.Binding, ci.edges)]
println("reached instances without the bit whose edges are bindings only (open issue 187): ", length(binonly))
# edges that name a callee without its CodeInstance, among instances the walk calls deep
nonci(ci) = [x for x in ci.edges if (x isa Core.MethodInstance && x !== ci.def) || x isa Method]
dmi = [ci for ci in reach if dwalk(ci) && !isempty(nonci(ci))]
println("deep by the walk and naming a callee by MethodInstance or Method: ", length(dmi), " of ", count(dwalk, collect(reach)))
function micode(x)   # the valid CodeInstances of Julia's owner a MethodInstance edge's callee has now
    x isa Core.MethodInstance && isdefined(x, :cache) || return Core.CodeInstance[]
    out = Core.CodeInstance[]; c = x.cache
    while true; valid(c) && c.owner === nothing && push!(out, c); isdefined(c, :next) || break; c = c.next; end
    out
end
codedeep(c) = c in reach ? dwalk(c) : rawbit(c)     # outside the walk's reach, the bit stands for the class
dmi_bad = [ci for ci in dmi if any(x -> any(c -> !codedeep(c), micode(x)), nonci(ci))]
println("  of them with such a callee whose code now is not deep (or has no bit): ", length(dmi_bad))
for ci in dmi_bad[1:min(end, 5)]; println("   ", first(string(ci.def.specTypes), 160)); end
# the calls that only throw, below the own facts instances
tdirect = unique([c for ci in factsown for c in callees(ci) if throwonly(c)])
println("callees that only throw, called directly by own facts instances: ", length(tdirect), " instances; not deep by the walk ", count(!dwalk, tdirect))
# exposure (D-6's G1 condition): a throw-only callee whose `Union{}` may rest on a callee: it names a callee whose
# result is `Union{}`, or a callee by MethodInstance or Method only
exposed(c) = any(x -> (x isa Core.CodeInstance && throwonly(x)) || x isa Core.MethodInstance || x isa Method, c.edges)
println("  of them whose `Union{}` may rest on a callee: ", count(exposed, tdirect))
bym = Dict{String,Int}(); for c in tdirect; m = c.def.def; k = string(m.module, ".", m.name); bym[k] = get(bym, k, 0) + 1; end
println("  by method: ", join(["$k $v" for (k, v) in sort(collect(bym); by = last, rev = true)[1:min(end, 25)]], ", "))
for c in filter(exposed, tdirect)[1:min(end, 8)]; println("   exposed: ", first(string(c.def.specTypes), 160)); end
# the loads
tl = @elapsed for p in pk; Core.eval(Main, Meta.parse("using $p")); end
println("the loads: ", round(tl; digits = 1), " s")
lost(set) = [ci for ci in set if !valid(ci)]
for (name, set) in (("image", image), ("made", made))
    l = lost(set)
    println(name, ": the loads end ", length(l), " of ", length(set), " | facts ", count(isfacts, l), " | bit ", count(rawbit, l),
            " | deep: walk ", count(dwalk, l), ", corrected ", count(dcorr, l), ", throw-only facts callers ", count(dthrowf, l), ", every caller ", count(dthrowa, l))
    for ci in l; (rawbit(ci) || dwalk(ci) || dcorr(ci)) && println("   ended and deep (bit ", rawbit(ci), ", walk ", dwalk(ci), ", corrected ", dcorr(ci), "): ", first(string(ci.def.specTypes), 160)); end
end
below = [ci for ci in reach if !(rootof(ci) in CORE8)]
println("below, outside the own modules: ", length(below), " | ended ", count(!valid, below), " | of the ended: bit ", count(ci -> !valid(ci) && rawbit(ci), below),
        ", deep by the walk ", count(ci -> !valid(ci) && dwalk(ci), below), ", corrected ", count(ci -> !valid(ci) && dcorr(ci), below),
        ", throw-only facts callers ", count(ci -> !valid(ci) && dthrowf(ci), below))
d2 = Base.invokelatest(w); println("digest ", d1, d1 == d2 ? " (equal after)" : " DIFFERS")
