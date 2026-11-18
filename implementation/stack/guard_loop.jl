# W-112's companion probe (compiler §5.6, C-59): a loop over a guarded call; where the guard's load sits
# and what the guarded call's result type does to the loop. Usage: julia --project=. stack/guard_loop.jl
using InteractiveUtils
using Traits
@trait X
struct S; v::Int; end
f(x) = x.v
f(x::X) = 0
function loop(v::Vector{S})
    t = 0
    for s in v
        t += f(s)
    end
    t
end
loop([S(1), S(2)])
code_llvm(stdout, loop, (Vector{S},); debuginfo=:none)
