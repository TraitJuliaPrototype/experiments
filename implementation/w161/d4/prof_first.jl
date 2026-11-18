# W-161, E-499's finding: where the first work of W-134's plain session spends its time on a build, by a
# profile of the work's first call: the share of samples in the compiler's functions of the facts mode and the
# membership machinery, by function name.
#     julia --project=<env_up or env_lib> prof_first.jl <csv>
const csv = ARGS[1]
using Profile, Statistics
@eval using CSV, DataFrames
w = @eval () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                 g = combine(groupby(df, names(df)[end]), c => sum); nothing)
Profile.init(n = 10^7, delay = 0.001)
t = @elapsed Profile.@profile Base.invokelatest(w)
io = IOBuffer()
Profile.print(IOContext(io, :displaysize => (10^6, 1000)); format = :flat, sortedby = :count, C = true)
text = String(take!(io))
total = something(tryparse(Int, something(match(r"Total snapshots: (\d+)", text), (; captures = ["0"])).captures[1]), 0)
names = ["edges_satisfy_g2", "set_g2!", "name_callee_code", "is_fact_sig", "declared_operation_result", "operation_entries!",
         "record_match_memberships!", "record_memberships!", "positive_fold_blocked", "subtype_membership",
         "membership_may_reach", "jl_membership_world_range", "typeinf_ext", "abstract_call_gf_by_type", "optimize",
         "jl_type_intersection", "jl_subtype_env", "ml_matches", "jl_compile_codeinst"]
println("first work ", round(1000t; digits = 1), " ms, snapshots ", total)
for n in names
    best = 0
    for l in split(text, '\n')
        occursin(n, l) || continue
        m = match(r"^\s*(\d+)", l)
        m === nothing && continue
        best = max(best, parse(Int, m.captures[1]))
    end
    println(rpad(n, 30), lpad(best, 7), "  ", total > 0 ? round(100best / total; digits = 1) : 0, " %")
end
