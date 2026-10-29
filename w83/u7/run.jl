# E-255 (U7): run a script (a test suite, a session) under the counting Compiler, then write the counts.
#
#     julia --threads=1 --project=<pkg> run.jl <tag> <script.jl> [dir]
#
# <tag>: the logs' name (logs/<tag>-all.tsv, logs/<tag>-open.tsv, logs/<tag>-summary.txt).
# <dir>: the directory the script runs in (default: the script's).
ENV["U7_TAG"] = ARGS[1]
const SCRIPT = abspath(ARGS[2])
const DIR = length(ARGS) >= 3 ? abspath(ARGS[3]) : dirname(SCRIPT)
include(joinpath(@__DIR__, "prelude.jl"))
cd(DIR)
# an outer test set: a failing test set inside the script does not end the run
using Test
try
    @testset "E-255 run" begin
        Base.include(Main, SCRIPT)
    end
catch e
    println(stderr, "the script ended with ", typeof(e))
finally
    report()
end
