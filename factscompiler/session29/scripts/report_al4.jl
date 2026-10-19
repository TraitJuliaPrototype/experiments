const csv = "/home/hellmann/Repos/julia-trait-bound/experiments/interfaces/App/data/sample.csv"
for p in split(get(ENV, "PK", "")); Core.eval(Main, Meta.parse("using $p")); end
@eval using TraitReport
function cis()
    s = Set{Any}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                ci.max_world == typemax(UInt) && push!(s, ci)
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    s
end
s0 = cis()
@time TraitReport.report(csv, joinpath(mktempdir(), "r.png"); io = IOBuffer())
for ci in setdiff(cis(), s0)
    println(rpad(repr(ci.owner), 10), " ", first(string(ci.def.specTypes), 230))
end
