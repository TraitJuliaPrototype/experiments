# E-457 (b), (c) (W-155b, D-12): the nine unrelated loads after the forks' work, with the runtime's list of
# deep endings on or off. With JULIA_TW_PIRATES=0 the report is off and the runtime keeps nothing; with
# W155B_COUNT=1 the report is off and this script takes the list itself, to count what the loads end of the
# deep class whoever defined it. Prints the loads' time, the endings and the reports.
#     julia --project=env_forks loads.jl <csv> <package>...
const csv = ARGS[1]; const pk = ARGS[2:end]
using CSV, DataFrames, TraitWorld
count = get(ENV, "W155B_COUNT", "0") == "1"
count && (TraitWorld.report_pirates!(false); ccall(:jl_set_deep_endings, Cint, (Cint,), 1))
w = @eval () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                 g = combine(groupby(df, names(df)[end]), c => sum); string(hash(repr((d, first(s, 3), g))); base = 16))
Base.invokelatest(w)
t = @elapsed for p in pk
    Core.eval(Main, Meta.parse("using $p"))
end
es = ccall(:jl_take_deep_endings, Any, ())
n = es isa Vector{Any} ? length(es) ÷ 3 : 0
println("loads ", round(t; digits = 2), " s | the report ", TraitWorld.REPORT_PIRATES[] ? "on" : "off",
        " | the runtime's list ", ccall(:jl_set_deep_endings, Cint, (Cint,), 1) != 0 ? "on" : "off",
        " | deep instances ended by the loads (counted here) ", n, " | pirate reports ", length(TraitWorld.PIRATE_REPORTS))
