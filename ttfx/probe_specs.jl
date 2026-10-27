# The specializations in the system image: their number, and the methods with most.
const _MT = isdefined(Core, :GlobalMethods) ? Core.GlobalMethods : Core.methodtable
tot = 0; per = Pair{Method,Int}[]
Base.visit(_MT) do m
    n = count(_ -> true, Base.specializations(m))
    global tot += n; push!(per, m => n)
end
sort!(per; by = last, rev = true)
println("methods ", length(per), "; specializations ", tot)
for (m, n) in per[1:8]; println("  ", n, "  ", m.module, ".", m.name, " ", m.sig isa DataType ? length(m.sig.parameters) - 1 : "?", " args"); end
