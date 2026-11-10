# E-355 (W-134 (a), (c)): E-41's control on the unified build. Does a package's code lose compiled code to
# unrelated loads?
#     julia --project=env_up|env_facts|env_forks lost.jl A|B <csv> <package>...
# Order A: the work, the loads, the work again. Order B: the loads, then the work.
# Counts the valid CodeInstances (owner nothing) of the modules loaded for the work, by root module:
# those the images brought, those the work made, and of each how many the loads end.
const order, csv = ARGS[1], ARGS[2]
const pk = ARGS[3:end]
const G2, FACTS = 0x10, 0x20
const CORE8 = (:CSV, :DataFrames, :Tables, :Parsers, :InlineStrings, :PooledArrays, :WeakRefStrings, :SentinelArrays)
const sys = Set(nameof(Base.moduleroot(m)) for m in values(Base.loaded_modules))
t0 = @elapsed @eval using CSV, DataFrames
const ROOTS = Set(nameof(Base.moduleroot(m)) for m in values(Base.loaded_modules) if !(nameof(Base.moduleroot(m)) in sys))
function tally()
    out = Tuple{Symbol,Core.CodeInstance}[]
    Base.visit(Core.methodtable) do m
        r = nameof(Base.moduleroot(m.module))
        r in ROOTS || return
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                ci.max_world == typemax(UInt) && ci.owner === nothing && push!(out, (r, ci))
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    return out
end
valid(ci) = ci.max_world == typemax(UInt)
function report(label, held)
    core = [(r, ci) for (r, ci) in held if r in CORE8]
    for (name, set) in (("the eight", core), ("all loaded for the work", held))
        n = length(set); f = count(x -> (x[2].flags & FACTS) != 0, set); g = count(x -> (x[2].flags & G2) != 0, set)
        lost = [(r, ci) for (r, ci) in set if !valid(ci)]
        by = Dict{Symbol,Int}(); for (r, _) in lost; by[r] = get(by, r, 0) + 1; end
        lf = count(x -> (x[2].flags & FACTS) != 0, lost)
        println(label, " | ", name, ": ", n, " (facts ", f, ", G2 ", g, "); lost ", length(lost), " (facts ", lf, ")",
                isempty(by) ? "" : "  [" * join(["$r $k" for (r, k) in sort(collect(by); by = last, rev = true)], ", ") * "]")
    end
end
w = @eval () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                 g = combine(groupby(df, names(df)[end]), c => sum); string(hash(repr((d, first(s, 3), g))); base = 16))
ms(t) = string(round(1000t; digits = 1), " ms")
println("order ", order, " | project ", basename(dirname(Base.active_project())), " | import ", ms(t0), " | roots ", length(ROOTS), " | loads: ", join(pk, " "))
image = tally()
if order == "A"
    t1 = @elapsed (d1 = Base.invokelatest(w)); t1b = @elapsed Base.invokelatest(w)
    seen = IdSet{Any}(ci for (_, ci) in image)
    made = [(r, ci) for (r, ci) in tally() if !(ci in seen)]
    tl = @elapsed for p in pk; Core.eval(Main, Meta.parse("using $p")); end
    t2 = @elapsed (d2 = Base.invokelatest(w)); t2b = @elapsed Base.invokelatest(w)
    println("work: first ", ms(t1), ", again ", ms(t1b), "; the loads ", ms(tl), "; after the loads ", ms(t2), ", again ", ms(t2b), " | digest ", d1, d1 == d2 ? " (equal after)" : " DIFFERS after: $d2")
    report("image code", image); report("made by the work", made)
else
    tl = @elapsed for p in pk; Core.eval(Main, Meta.parse("using $p")); end
    t1 = @elapsed (d1 = Base.invokelatest(w)); t1b = @elapsed Base.invokelatest(w)
    println("the loads ", ms(tl), "; work: first ", ms(t1), ", again ", ms(t1b), " | digest ", d1)
    report("image code", image)
end
