# W-158, fourth part: the library's test/verify.jl in a session, PATCH=1 with patch_f.jl laid over first.
# Run in the library's tree: (cd wt/w158b-tw && [PATCH=1] $J --project=. $W158/f-probes/verify.jl)
get(ENV, "PATCH", "0") == "1" && include(joinpath(@__DIR__, "patch_f.jl"))
include(joinpath(pwd(), "test", "verify.jl"))
