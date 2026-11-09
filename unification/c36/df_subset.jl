# DataFrames' upstream test files named on the command line, in Pkg.test's sandbox (the test
# dependencies), in this process: compiler C-36's cases (open issue 158, `tables.jl:86`; E-305's
# three `@inferred`: `data.jl`, `dataframe.jl`, `sort.jl`).
#   cd forks-unified && julia --project=env_forks ../experiments/unification/c36/df_subset.jl tables.jl data.jl
using Pkg
const FILES = isempty(ARGS) ? ["tables.jl"] : copy(ARGS)
Pkg.test("DataFrames"; test_fn = () -> begin
    dir = joinpath(dirname(dirname(Base.find_package("DataFrames"))), "test")
    @eval Main using DataFrames, Dates, Test, Random, InlineStrings
    for f in FILES
        println("== ", f)
        try
            Base.include(Main, joinpath(dir, f))
        catch err
            println("FILE ", f, " ended: ", sprint(showerror, err)[1:min(end, 300)])
        end
    end
    exit(0)
end)
