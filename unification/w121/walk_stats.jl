# E-287 (W-121, phase 1): the dispatch walk's counters around each load, in ARGS' order.
#     julia --project=<env> walk_stats.jl Pkg1 Pkg2 ...
st() = [ccall(:jl_membership_stat, Csize_t, (Cint,), k) for k in 0:6]
const NAMES = ["memberships", "replays", "visits", "morespec_skips", "instances_stamped", "cache_lowerings", "latest_only_clears"]
for p in ARGS
    s0 = st(); t = @elapsed Core.eval(Main, :(using $(Symbol(p)))); s1 = st()
    println("C ", p, " ", round(t, digits = 3), " s: ", join(["$(NAMES[k]) $(s1[k] - s0[k])" for k in 1:7 if s1[k] != s0[k]], ", "))
end
