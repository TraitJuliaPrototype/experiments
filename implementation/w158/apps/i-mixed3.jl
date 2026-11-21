# W-158, fifth part (E-510; compiler C-156): apps/i-ctor3.jl's constructor at three `Callable` signatures, past the
# bound of the product, given boxes beside plain functions: boxes made by the user at the first and second
# signatures, and a box of the wrong signature, which no method takes (`MethodError`, as in a session). The forwarder
# passes a box as it is and calls the method as written at the boxes. A wrapper given so: apps/i-wrap3.jl.
# `julia --project=<TraitWorld> apps/i-mixed3.jl` runs `main` in a session.
include(joinpath(@__DIR__, "i-ctor3.jl"))
const D1 = Dynamic{Callable{Tuple{Float64}, Float64}}
const D2 = Dynamic{Callable{Tuple{Int}, Float64}}
function (@main)(args::Vector{String})::Cint
    n = length(args)
    println(Core.stdout, "plain ", enter3([pick(n + k) for k in 1:5]))
    println(Core.stdout, "kept ", enter3([Raw3(D1(c3), a4, i5), Raw3(c1, D2(a1), i2), Raw3(D1(c2), D2(a5), i1)]))
    r = try
        string(enter3([Raw3(D2(a3), a2, i3)]))
    catch e
        e isa MethodError ? "MethodError" : "another error"
    end
    println(Core.stdout, "a box of another signature: ", r)
    return 0
end
