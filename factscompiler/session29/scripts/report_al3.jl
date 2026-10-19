const csv = "/home/hellmann/Repos/julia-trait-bound/experiments/interfaces/App/data/sample.csv"
for p in split(get(ENV, "PK", "")); Core.eval(Main, Meta.parse("using $p")); end
@eval using TraitReport
println(stderr, "=== WORK")
@time TraitReport.report(csv, joinpath(mktempdir(), "r.png"); io = IOBuffer())
