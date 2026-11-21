# C-157, the smallest program: `passes` over a Vector{Callable{Tuple{Float64}, Bool}} with an element returning an Int.
# PRE=<n> runs a preceding statement first (see `pre` below); PRE unset: a fresh session.
using TraitWorld
module Sig
using TraitWorld
@trait_module
export passes
function passes(tests::Vector{Callable{Tuple{Float64}, Bool}}, x::Float64)
    n = 0
    for t in tests
        t(x) && (n += 1)
    end
    return n
end
end
using .Sig
pre = get(ENV, "PRE", "")
if pre == "ok"        # the same call with a well-typed element first
    println("pre: ", passes(Callable{Tuple{Float64}, Bool}[x -> x > 1.0, iszero], 2.0))
end
r = try
    passes(Callable{Tuple{Float64}, Bool}[x -> 1], 2.0)
catch e
    e
end
println("PRE=", repr(pre), " result: ", r isa Exception ? sprint(showerror, r) : repr(r))
