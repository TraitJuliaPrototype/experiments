using CSV, DataFrames, Statistics, Dates
D = ENV["DATA"]; tmp = tempname()
disp(x) = (show(devnull, MIME"text/plain"(), x); nothing)
const MARKS = Ref{Any}(nothing)
@noinline mark(::Val{N}) where {N} = (MARKS[] = N; nothing)
macro step(name, ex)
    quote
        Base.invokelatest(mark, Val($(QuoteNode(name))))
        local t = time(); local r = $(esc(ex)); disp(r)
        println(stderr, rpad($(string(name)), 16), round(time() - t, digits = 3))
    end
end
@step read (global df = CSV.read(joinpath(D, "people.csv"), DataFrame))
@step describe describe(df)
@step select_filter subset(select(df, :id, :city, :income), :income => ByRow(x -> !ismissing(x) && x > 5e4))
@step sort sort(df, [:city, :income], rev = [false, true])
@step groupby combine(groupby(df, :city), :income => mean ∘ skipmissing => :mean_income, nrow)
@step user_function transform(df, [:age, :income] => ByRow((a, i) -> coalesce(i, 0.0) / max(coalesce(a, 1), 1)) => :ratio)
@step join innerjoin(df, CSV.read(joinpath(D, "orders.csv"), DataFrame), on = :id)
@step write CSV.write(tmp, df)
