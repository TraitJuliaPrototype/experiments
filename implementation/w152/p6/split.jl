# E-399 (W-152; the review of 2026-11-15, P6): what a load validates, by deep G2 (E-395's class), after
# E-325's `w121/g2_split.jl`; and the definitions in the session that an image's code could not have known.
#     SPLIT_FIRST="OffsetArrays StatsBase ..." julia --project=<env> split.jl <package>...
# For each package of ARGS, in order: the instances its load brings from images, in three classes
# (deep G2; the G2 bit, not deep; no bit), with their edges by kind. "Call by signature" is the lookup
# validation pays for (E-304, E-325).
using TraitWorld
const FROM_IMAGE = 0x04; const G2 = 0x10; const FACTS = 0x20
first_loads = split(get(ENV, "SPLIT_FIRST", ""))
function all_cis()
    out = Base.IdSet{Core.CodeInstance}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance && isdefined(mi, :cache) || continue
            ci = mi.cache
            while true; push!(out, ci); isdefined(ci, :next) || break; ci = ci.next; end
        end
    end
    out
end
onlybindings(ci) = all(x -> x isa Core.Binding, ci.edges)
bit(ci) = (ci.flags & G2) != 0 || onlybindings(ci)
callees(ci) = Core.CodeInstance[x for x in ci.edges if x isa Core.CodeInstance]
function notdeep_of(roots)
    seen = IdSet{Any}(); stack = Any[roots...]; rev = IdDict{Any,Vector{Any}}(); nd = IdSet{Any}()
    while !isempty(stack)
        ci = pop!(stack); ci in seen && continue; push!(seen, ci)
        for c in callees(ci); push!(get!(rev, c, Any[]), ci); c in seen || push!(stack, c); end
    end
    work = Any[ci for ci in seen if !bit(ci)]; foreach(ci -> push!(nd, ci), work)
    while !isempty(work); c = pop!(work); for p in get(rev, c, Any[]); p in nd || (push!(nd, p); push!(work, p)); end; end
    nd
end
function edge_kinds!(kinds, ci)
    e = ci.edges; j = 1
    while j <= length(e)
        x = e[j]
        k = x isa Core.CodeInstance ? "CodeInstance" : x isa Core.MethodInstance ? "MethodInstance" : x isa Int ? "call by signature" :
            x isa Core.Binding ? "Binding" : x isa Type ? "invoke signature" : string(typeof(x).name.name)
        kinds[k] = get(kinds, k, 0) + 1
        j += x isa Int ? 2 + abs(x) : (x isa Type ? 2 : 1)
    end
end
methods_now() = (s = IdSet{Any}(); Base.visit(m -> push!(s, m), Core.methodtable); s)
t1 = @elapsed for p in first_loads; Core.eval(Main, Meta.parse("using $p")); end
isempty(first_loads) || println("loaded first: ", join(first_loads, " "), " in ", round(t1; digits = 2), " s")
tot = Dict{String,Vector{Int}}()
for p in ARGS
    before = all_cis(); mbefore = methods_now(); modsbefore = Set(values(Base.loaded_modules))
    t = @elapsed Core.eval(Main, Meta.parse("using $p"))
    new = [ci for ci in all_cis() if !(ci in before) && (ci.flags & FROM_IMAGE) != 0]
    nd = notdeep_of(new)
    println("== ", p, ": load ", round(t; digits = 3), " s; instances from images ", length(new))
    for (label, pred) in (("deep G2", ci -> !(ci in nd)), ("the bit, not deep", ci -> (ci in nd) && bit(ci)), ("no bit", ci -> !bit(ci)))
        set = filter(pred, new); kinds = Dict{String,Int}(); foreach(ci -> edge_kinds!(kinds, ci), set)
        e = sum(values(kinds); init = 0); s = get(kinds, "call by signature", 0)
        v = get!(tot, label, [0, 0, 0]); v[1] += length(set); v[2] += e; v[3] += s
        println("  ", rpad(label, 18), lpad(length(set), 6), " instances (facts ", count(ci -> (ci.flags & FACTS) != 0, set), "), ", lpad(e, 7), " edges: ",
                join(["$k $n" for (k, n) in sort(collect(kinds); by = last, rev = true)], ", "))
    end
    # what the images of this load could not have known: the methods in the session before it whose module
    # none of the newly loaded modules' images depends on is not known here; the count below is the upper
    # bound, every method the session held before this load, and of them the pirates by the letter
    newmods = [m for m in values(Base.loaded_modules) if !(m in modsbefore)]
    println("  modules this load brings: ", length(newmods))
end
println("\nall loads: ", join(["$k: $(v[1]) instances, $(v[2]) edges, $(v[3]) calls by signature" for (k, v) in tot], " | "))
s = sum(v[3] for v in values(tot)); i = sum(v[1] for v in values(tot)); e = sum(v[2] for v in values(tot))
d = tot["deep G2"]; println("deep G2 holds ", round(100d[1] / i; digits = 1), " % of the instances, ", round(100d[2] / e; digits = 1), " % of the edges, ", round(100d[3] / max(s, 1); digits = 1), " % of the calls by signature")
# the definitions foreign to the measured packages: methods of the packages loaded first, and the pirates by the letter among them
if !isempty(first_loads)
    roots = Set(Symbol.(first_loads)); n = 0; np = 0; byr = Dict{Symbol,Int}()
    sysmods = Set([:Core, :Base])
    Base.visit(Core.methodtable) do m
        r = nameof(Base.moduleroot(m.module))
        o = TraitWorld.owner(m.module)
        (o === :Julia) && return
        global n += 1
        if !TraitWorld.owned_method(m); global np += 1; byr[r] = get(byr, r, 0) + 1; end
    end
    println("methods of packages in the session (not Julia's own): ", n, "; pirates by the letter: ", np, "  ", join(["$k $v" for (k, v) in sort(collect(byr); by = last, rev = true)[1:min(end, 12)]], ", "))
end
