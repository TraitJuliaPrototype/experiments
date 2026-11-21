# W-158, fifth part (E-510; compiler C-156): apps/i-mixed3.jl with a wrapper (`compiled_for(i5)`) given at the third
# signature through the record's field typed bare `Callable`. The wrapper is a member by use of every signature
# (every function is a member of every `Callable{A, S}`), so each argument's kept form is one of two types (the
# box or the wrapper; a wrapper is compiled per object type): the call of the method as written at them has 8
# combinations, past Julia's union split of 4, and is left to dispatch; so is `usetrip` at its result. 4 errors
# in a trimmed build (f1d6e51efa). A split of a union of kept forms up to 64 would serve the call; Julia's join
# of the 8 results, `Trip`, would still leave `usetrip` to dispatch.
# `julia --project=<TraitWorld> apps/i-wrap3.jl` runs `main` in a session.
include(joinpath(@__DIR__, "i-ctor3.jl"))
const D1 = Dynamic{Callable{Tuple{Float64}, Float64}}
const D2 = Dynamic{Callable{Tuple{Int}, Float64}}
function (@main)(args::Vector{String})::Cint
    n = length(args)
    println(Core.stdout, "plain ", enter3([pick(n + k) for k in 1:5]))
    println(Core.stdout, "kept ", enter3([Raw3(D1(c3), a4, compiled_for(i5)), Raw3(c1, D2(a1), i2), Raw3(D1(c2), D2(a5), i1)]))
    r = try
        string(enter3([Raw3(D2(a3), a2, i3)]))
    catch e
        e isa MethodError ? "MethodError" : "another error"
    end
    println(Core.stdout, "a box of another signature: ", r)
    return 0
end
