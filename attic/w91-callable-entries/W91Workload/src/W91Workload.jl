# E-241: a stand-in for a forks' workload that covers the session's two `ByRow` steps over columns with missing
# values (forks/scripts/session.jl: `select_filter`, `user_function`). The functions are its own; the entries of
# `Callable` they reach (`enter_callable` at `Callable{Tuple{Union{Missing, Float64}}, Bool}` and at
# `Callable{Tuple{Union{Missing, Int64}, Union{Missing, Float64}}, Float64}`) do not depend on the function.
module W91Workload
using DataFrames
using PrecompileTools: @compile_workload
@compile_workload begin
    df = DataFrame(id = [1, 2, 3], age = Union{Missing, Int}[42, missing, 30], income = Union{Missing, Float64}[1.5, 2.5, missing])
    subset(select(df, :id, :income), :income => ByRow(x -> !ismissing(x) && x > 2.0))
    transform(df, [:age, :income] => ByRow((a, i) -> coalesce(i, 1.0) * coalesce(a, 2)) => :r)
end
end
