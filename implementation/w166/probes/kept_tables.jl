# W-166 (from W-156's probe): TraitTables' column code given a column in each form, a plain member, a box and a
# wrapper (traits §7.4: a method gives the same results for a member and for its kept forms). Storage keeps the
# form given (§8), so a table may hold a box or a wrapper as a column.
#     $JN --project=../w156/env_demo probes/kept_tables.jl
using TraitWorld, TraitTables
const TC = TraitTables.TableCore
v = [3.0, 1.0, 2.0]
for (name, c) in (("plain", v), ("box", Dynamic{Column{Float64}}(v)), ("wrapper", compiled_for(v)))
    t = TraitTables.table("x" => copy(v))
    TC.addcolumn!(t, "c", c)
    r = try
        s = TC.sortby(t, "c")
        d = TC.describe(t)[2]
        (sorted = TC.floats(s, "x"), sortedcol = typeof(s["c"]), mean = d.mean, eltype = d.eltype,
         take = typeof(TC.take(c, [1, 2])), floats = TC.floats(c))
    catch e
        sprint(showerror, e)[1:min(end, 300)]
    end
    println(rpad(name, 8), " ", typeof(t["c"]), " => ", r)
end
