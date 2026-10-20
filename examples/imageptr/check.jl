# Correctness item 2: a `Dynamic{Callable}` kept as a constant in a package image, called in a new session.
# Its pointer belongs to the session that built the image: it must be made again, not called.
#     julia --project=imageptr/env imageptr/check.jl
include(joinpath(@__DIR__, "..", "common.jl"))
using ErasedP
check("a Dynamic{Callable} kept in a package image is called correctly in a new session", ErasedP.call(3.0) == 6.0 && ErasedP.D(4.0) == 8.0)
summary()
