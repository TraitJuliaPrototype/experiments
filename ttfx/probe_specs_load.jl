# The specializations a load adds, and where.
const _MT = isdefined(Core, :GlobalMethods) ? Core.GlobalMethods : Core.methodtable
function census()
    d = IdDict{Method,Int}(); Base.visit(_MT) do m; d[m] = count(_ -> true, Base.specializations(m)); end; d
end
c0 = census()
t = @elapsed @eval using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, CairoMakie
c1 = census()
added = [(n - get(c0, m, 0), m) for (m, n) in c1]
println("load ", round(t; digits = 2), " s; specializations added ", sum(first, added), "; to methods existing before the load ",
        sum(a for (a, m) in added if haskey(c0, m)))
sort!(added; by = first, rev = true)
for (a, m) in added[1:10]; println("  +", a, "  ", m.module, ".", m.name, " (now ", c1[m], ")"); end
