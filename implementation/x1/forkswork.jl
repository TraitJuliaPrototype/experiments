# E-265's work step for the forks' session: scripts/session.jl's steps after the imports, up to the second
# schema (the REPL's display as `show` with :limit into devnull); InlineStrings' load left out.
let D = ENV["X1_DATA"], tmp = tempname(), io = IOContext(devnull, :limit => true, :displaysize => (40, 120))
    disp(x) = (show(io, MIME"text/plain"(), x); nothing)
    df = CSV.read(joinpath(D, "people.csv"), DataFrame); disp(df)
    disp(describe(df))
    disp(subset(select(df, :id, :city, :income), :income => ByRow(x -> !ismissing(x) && x > 5e4)))
    disp(sort(df, [:city, :income], rev = [false, true]))
    disp(combine(groupby(df, :city), :income => mean ∘ skipmissing => :mean_income, nrow))
    disp(transform(df, [:age, :income] => ByRow((a, i) -> coalesce(i, 0.0) / max(coalesce(a, 1), 1)) => :ratio))
    disp(innerjoin(df, CSV.read(joinpath(D, "orders.csv"), DataFrame), on = :id))
    df.income_k = df.income ./ 1000
    CSV.write(tmp, df)
    s2 = CSV.read(joinpath(D, "sensors.csv"), DataFrame); disp(s2)
    disp(describe(s2))
    disp(sort(s2, [:tag, :s1]))
    disp(combine(groupby(s2, :tag), :s1 => mean ∘ skipmissing => :m1, :s2 => maximum ∘ skipmissing => :x2, nrow))
end
