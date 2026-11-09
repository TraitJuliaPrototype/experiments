# The load profile: where loading packages spends its time, C frames included. Writes a flat profile
# (inclusive and self samples per frame, 1 ms each) and a tree (to depth 60). Found validation's share
# of the goal's load (E-334).
#     julia-unified/julia --startup-file=no --project=<env> experiments/unification/audit/profile_load.jl Pkg,… <flat.log> <tree.log>
# The samples of all threads are listed; the main thread's are those under `_start`.
using Profile
Profile.init(n = 10^7, delay = 0.001)
const pkgs = [Symbol(p) for p in split(ARGS[1], ',')]
@profile Core.eval(Main, Expr(:using, (Expr(:., p) for p in pkgs)...))
popfirst!(ARGS)
# flat: the C and Julia frames with the most samples (inclusive), as a share of all samples
data, lidict = Profile.retrieve()
open(ARGS[1], "w") do io
    Profile.print(io, data, lidict; format = :flat, sortedby = :count, C = true, mincount = 150, maxdepth = 200)
end
open(ARGS[2], "w") do io
    Profile.print(IOContext(io, :displaysize => (2000, 250)), data, lidict; format = :tree, C = true, mincount = 200, maxdepth = 60, noisefloor = 2)
end
