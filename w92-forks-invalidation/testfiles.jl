# E-238: DataFrames' test files for the code a change touches (not the whole suite), in a forks tree's env_forks
# stacked over env_testdeps (the test dependencies, offline):
#     JULIA_LOAD_PATH="<forks>/env_forks:env_testdeps:@stdlib" julia testfiles.jl <forks>/DataFrames/test cat.jl …
using DataFrames, Dates, Test, Random, InlineStrings
dir = ARGS[1]
for f in ARGS[2:end]
    t = time()
    @testset "$f" begin
        include(joinpath(dir, f))
    end
    println("F ", f, " ", round(time() - t; digits = 1), " s")
end
