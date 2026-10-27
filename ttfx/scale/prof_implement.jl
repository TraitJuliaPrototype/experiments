# E-171: where a new type's @implement spends its time in ScaleL (a sampling profile, not timed).
using ScaleL, Profile
C = ScaleL.Core_
@eval Main struct TNew; v::Float64; w::Vector{Float64}; end
@eval Main struct TNew2; v::Float64; w::Vector{Float64}; end
# a first implement compiles the machinery's paths; the second is profiled
@eval Main $(C).@implement $(C).Tr1 TNew begin a1(x) = x.v; b1(x, y) = x.v * y; c1(x) = x.w end
Profile.init(n = 10^7, delay = 0.001)
@profile @eval Main $(C).@implement $(C).Tr1 TNew2 begin a1(x) = x.v; b1(x, y) = x.v * y; c1(x) = x.w end
Profile.print(format = :flat, sortedby = :count, mincount = 30, noisefloor = 0, C = false)
