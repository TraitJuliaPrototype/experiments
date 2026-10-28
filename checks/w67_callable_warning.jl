# W-67 (closed open issue §2.20): a Callable without a method at its declared signature, in both attributes: MethodError, no misleading warning.
#     julia --project=TraitWorld experiments/checks/w67_callable_warning.jl
using TraitWorld
@trait_module module CW
using TraitWorld
export apply1, apply1c
apply1(f::Callable{Tuple{Float64},Float64}, x::Float64) = f(x)
apply1c(f::Compiled{Callable{Tuple{Float64},Float64}}, x::Float64) = f(x)
end
using .CW
g(x::Int) = 2x                    # no method at Float64
h(x) = error("never")             # a method that always throws
for (name, call) in (("dynamic, no method", () -> apply1(g, 1.0)), ("compiled, no method", () -> apply1c(compiled_for(g), 1.0)),
                     ("dynamic, throws", () -> apply1(h, 1.0)), ("compiled, throws", () -> apply1c(compiled_for(h), 1.0)))
    r = try call(); "returned" catch e; first(sprint(showerror, e), 200) end
    println("== ", name, ": ", replace(r, '\n' => " | "))
end
