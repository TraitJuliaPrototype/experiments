# C-157, diagnosis: the backtrace of the error, and the call after `precompile` / after code_typed.
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
const T = Vector{Callable{Tuple{Float64}, Bool}}
mode = get(ENV, "MODE", "")
mode == "precompile" && println("precompile: ", precompile(passes, (T, Float64)))
mode == "typed" && Base.code_typed(passes, (T, Float64))
try
    passes(Callable{Tuple{Float64}, Bool}[x -> 1], 2.0)
catch e
    println("MODE=", mode, ": ", sprint(showerror, e))
    Base.show_backtrace(stdout, catch_backtrace()); println()
end
