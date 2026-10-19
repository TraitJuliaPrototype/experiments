# The work after the loads with PlainRTInterp not optimizing (a run-time override, set before the
# work), and every plain `return_type` answer of the session, to compare with the default.
#     NOOPT=1|0 julia -J facts/sys.so afterloads_noopt.jl <csv> <out.txt> <package>...
const csv = ARGS[1]; outf = ARGS[2]; pk = ARGS[3:end]
const CC = Base.Compiler
get(ENV, "NOOPT", "0") == "1" && @eval CC.may_optimize(::CC.PlainRTInterp) = false
using CSV, DataFrames
w = @eval () -> (df = CSV.read($csv, DataFrame); describe(df); c = names(df)[1]; sort(df, c); combine(groupby(df, names(df)[end]), c => sum); nothing)
t1 = @elapsed Base.invokelatest(w); Base.invokelatest(w)
for p in pk; Core.eval(Main, Meta.parse("using $p")); end
t2 = @elapsed Base.invokelatest(w)
println("NOOPT=", get(ENV, "NOOPT", "0"), "  work: first ", round(1000t1; digits = 1), " ms; after the loads ", round(1000t2; digits = 1), " ms")
# the answers: every valid CodeInstance of the plain return_type cache, its signature and result
ans = String[]
Base.visit(Core.methodtable) do m
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance && isdefined(mi, :cache) || continue
        ci = mi.cache
        while true
            if ci.owner === :facts_plain_return_type && ci.max_world == typemax(UInt)
                r = isdefined(ci, :rettype_const) ? "const " * repr(ci.rettype_const) : string(ci.rettype)
                push!(ans, string(mi.specTypes) * " => " * first(r, 300) * "  effects " * string(ci.ipo_purity_bits, base = 16))
            end
            isdefined(ci, :next) || break; ci = ci.next
        end
    end
end
open(io -> foreach(s -> println(io, s), sort!(ans)), outf, "w")
println(length(ans), " answers")
