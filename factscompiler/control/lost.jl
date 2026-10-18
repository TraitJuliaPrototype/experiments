# The control (session 29): does plain code compiled by facts (`all`, the facts system image) lose
# compiled code to unrelated loads, as plain code compiled plainly does? Same work, same loads.
#
#     julia [-J facts/sys.so] lost.jl plaintables|upstream <csv> <package>...
#
# Counts valid CodeInstances per library (by root module) after the work, then after loading the
# packages, and the time of the same work again after the loads.
const which, csv = ARGS[1], ARGS[2]
pk = ARGS[3:end]
const ROOTS = which == "plaintables" ? (:PlainTables, :TraitMakie) : (:CSV, :DataFrames, :Tables, :Parsers, :InlineStrings, :PooledArrays, :WeakRefStrings, :SentinelArrays)
which == "plaintables" ? (@eval using PlainTables, TraitMakie) : (@eval using CSV, DataFrames)
println("mode: ", Base.Compiler.NativeInterpreter().facts ? "all (facts)" : "plain", "  loads: ", join(pk, " "))
function tally(out = nothing)
    d = Dict{Symbol,Int}()
    Base.visit(Core.methodtable) do m
        r = nameof(Base.moduleroot(m.module))
        r in ROOTS || return
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                if ci.max_world == typemax(UInt) && ci.owner === nothing
                    d[r] = get(d, r, 0) + 1
                    out === nothing || push!(out, (r, ci))
                end
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    return d
end
png = joinpath(get(ENV, "TMPDIR", tempdir()), "lost.png")
if which == "plaintables"
    w = @eval () -> (t = PlainTables.readcsv($csv); PlainTables.summary_text(t); x = PlainTables.floats(t, PlainTables.colnames(t)[1]);
                     f = TraitMakie.hist(x; bins = 24, title = "i", size = (1200, 800)); TraitMakie.vlines!(f, sum(x) / length(x); color = :red); TraitMakie.save($png, f))
else
    w = @eval () -> (df = CSV.read($csv, DataFrame); describe(df); c = names(df)[1]; sort(df, c); combine(groupby(df, names(df)[end]), c => sum); nothing)
end
t1 = @elapsed Base.invokelatest(w)
t1b = @elapsed Base.invokelatest(w)
held = Tuple{Symbol,Core.CodeInstance}[]
before = tally(held)
for p in pk; Core.eval(Main, Meta.parse("using $p")); end
after = tally()
t2 = @elapsed Base.invokelatest(w)
fmt(d) = join(["$r $(get(d, r, 0))" for r in ROOTS if haskey(before, r) || haskey(d, r)], ", ")
lostby = Dict{Symbol,Int}()
for (r, ci) in held
    ci.max_world == typemax(UInt) || (lostby[r] = get(lostby, r, 0) + 1)
end
lost = sum(values(lostby); init = 0)
println("work: first ", round(1000t1; digits = 1), " ms, again ", round(1000t1b; digits = 1), " ms; after the loads ", round(1000t2; digits = 1), " ms")
println("valid before the loads: ", fmt(before))
println("valid after the loads:  ", fmt(after))
println("lost: ", lost, " of ", length(held), "  (", join(["$r $n" for (r, n) in lostby], ", "), ")")
