# W-158, fourth part: the ODE program's check round by round (../probes/rounds.jl), printing the code of the instances
# whose name matches SHOWCODE (a regex; default rodas5_step!). PATCH=1 lays patch_f.jl over first.
get(ENV, "PATCH", "0") == "1" && include(joinpath(@__DIR__, "patch_f.jl"))
include(get(ENV, "APP", joinpath(@__DIR__, "..", "..", "w135", "apps", "ode.jl")))
include(joinpath(@__DIR__, "..", "probes", "rounds.jl"))
check_rounds(main, (Vector{String},); showcode = Regex(get(ENV, "SHOWCODE", "rodas5_step!")))
