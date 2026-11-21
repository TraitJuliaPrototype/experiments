# W-158, fifth part (E-510; compiler C-156, C-86): apps/i-ctor3.jl's constructor at three `Callable` signatures, past
# the bound of the product, with one value the build does not count: `c6` is reached only as the 4,097th element of
# a constant, past the 4,096 elements a build reads of a constant. The forwarder boxes each argument apart over its
# own members; `c6` is no member of the first signature, so the binary raises `MethodError` at that argument's
# branch where the session returns (G1: an error, never another member's code). The other records are counted.
# `julia --project=<TraitWorld> apps/i-gap3.jl` runs `main` in a session.
include(joinpath(@__DIR__, "i-ctor3.jl"))
c6(x::Float64) = 3x
const GS = Callable[Any[c1 for _ in 1:4096]..., c6]
function (@main)(args::Vector{String})::Cint
    n = length(args)
    println(Core.stdout, "counted ", enter3([pick(n + k) for k in 1:5]))
    g = GS[4096 + n + 1]
    r = try
        string(enter3([Raw3(g, a2, i3)]))
        # (the session's answer: c6(1.5) + a2(2) + i3(3, 0.5) = 4.5 + 4.0 - 2.5 = 6.0)
    catch e
        e isa MethodError ? "MethodError" : "another error"
    end
    println(Core.stdout, "gap ", r)
    return 0
end
