# E-357 (W-134 (a), E-30's form): E-355's control for the demonstrators' images on the unified build.
#     julia --project=env_demo lost_demo.jl D|Dp|T|Tp A|B <csv> <outdir> <package>...
# D: TraitDifferentialEquations and TraitMakie (two solves and their plot). Dp: the plain twins PlainODE, PlainPlots.
# T: TraitCSV, TraitTables, TraitMakie (a read, a summary, a histogram). Tp: PlainTables, PlainPlots.
# Order A: the work, the loads, the work again. Order B: the loads, then the work.
# Counts the valid CodeInstances (owner nothing) of the session's own packages (every root module the session's
# `using` brings that the system image does not hold), by root module.
const kind, order, csv, out = ARGS[1:4]
const pk = ARGS[5:end]
const G2, FACTS = 0x10, 0x20
const sys = Set(nameof(Base.moduleroot(m)) for m in values(Base.loaded_modules))
include("demo_session.jl")
const ROOTS = Set(nameof(Base.moduleroot(m)) for m in values(Base.loaded_modules) if !(nameof(Base.moduleroot(m)) in sys))
function tally(all = false)
    res = Tuple{Symbol,Core.CodeInstance}[]
    Base.visit(Core.methodtable) do m
        r = nameof(Base.moduleroot(m.module))
        all || r in ROOTS || return
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                ci.max_world == typemax(UInt) && ci.owner === nothing && push!(res, (r, ci))
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    return res
end
valid(ci) = ci.max_world == typemax(UInt)
function report(label, set)
    n = length(set); f = count(x -> (x[2].flags & FACTS) != 0, set); g = count(x -> (x[2].flags & G2) != 0, set)
    lost = [(r, ci) for (r, ci) in set if !valid(ci)]
    by = Dict{Symbol,Int}(); for (r, _) in lost; by[r] = get(by, r, 0) + 1; end
    lf = count(x -> (x[2].flags & FACTS) != 0, lost)
    println(label, ": ", n, " (facts ", f, ", G2 ", g, "); lost ", length(lost), " (facts ", lf, ")",
            isempty(by) ? "" : "  [" * join(["$r $k" for (r, k) in sort(collect(by); by = last, rev = true)], ", ") * "]")
    for (r, ci) in lost[1:min(end, 12)]; println("    lost: ", ci.def.specTypes); end
end
ms(t) = string(round(1000t; digits = 1), " ms")
timed(f) = (c0 = Base.cumulative_compile_time_ns(); t = @elapsed (d = Base.invokelatest(f)); c1 = Base.cumulative_compile_time_ns();
            (d, t, (c1[1] - c0[1]) / 1e9, (c1[2] - c0[2]) / 1e9))
show3(x) = string(ms(x[2]), " (compile ", ms(x[3]), ", recompile ", ms(x[4]), ")")
Base.cumulative_compile_timing(true)
println("kind ", kind, " order ", order, " | import ", ms(t0), " | roots ", length(ROOTS), ": ", join(sort(collect(ROOTS)), " "))
image = tally()
loads() = @elapsed for p in pk; Core.eval(Main, Meta.parse("using $p")); end
if order == "A"
    r1 = timed(w); r1b = timed(w)
    seen = IdSet{Any}(ci for (_, ci) in image)
    made = [(r, ci) for (r, ci) in tally() if !(ci in seen)]
    tl = loads()
    blist = tally(true)
    r2 = timed(w); r2b = timed(w)
    alist = tally(true); before = IdSet{Any}(ci for (_, ci) in blist)
    after = [(r, ci) for (r, ci) in alist if !(ci in before)]
    println("work: first ", show3(r1), ", again ", ms(r1b[2]), "; the loads ", ms(tl), "; after the loads ", show3(r2), ", again ", ms(r2b[2]),
            " | digest ", r1[1], r1[1] == r2[1] ? " (equal after)" : " DIFFERS after: $(r2[1])")
    report("image code", image); report("made by the work", made)
    by = Dict{Symbol,Int}(); for (r, _) in after; by[r] = get(by, r, 0) + 1; end
    println("compiled after the loads: ", length(after), "  [", join(["$r $k" for (r, k) in sort(collect(by); by = last, rev = true)], ", "), "]")
    for (r, ci) in after[1:min(end, parse(Int, get(ENV, "SHOW_AFTER", "0")))]; println("    after: ", (ci.flags & FACTS) != 0 ? "facts " : "plain ", ci.def.specTypes); end
else
    tl = loads()
    r1 = timed(w); r1b = timed(w)
    println("the loads ", ms(tl), "; work: first ", show3(r1), ", again ", ms(r1b[2]), " | digest ", r1[1])
    report("image code", image)
end
