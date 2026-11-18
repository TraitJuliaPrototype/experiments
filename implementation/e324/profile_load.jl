# E-324: where a load's time goes, C frames included: the flat profile of `using <packages>`.
#   julia --project=<env> profile_load.jl Pkg1,Pkg2,...
using Profile
pkgs = Symbol.(split(ARGS[1], ','))
Profile.init(n = 10^7, delay = 0.001)
t = @elapsed Profile.@profile for p in pkgs
    @eval using $p
end
println("load ", round(t, digits = 3), " s")
Profile.print(format = :flat, sortedby = :count, C = true, mincount = 200, maxdepth = 200)
