# W-156: DataFrames' own join test file (forks/DataFrames/test/join.jl) on the forks, the joins' key columns
# boxed at the door. Run from forks/DataFrames/test:  julia --project=<w156>/env_join <this file>
using Test
@testset "join.jl" begin
    include(joinpath(pwd(), "join.jl"))
end
