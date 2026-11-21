# C-157, variants: FORM=loop|all; MOD=trait|plain|main (where `passes` is defined)
using TraitWorld
form = get(ENV, "FORM", "loop"); where_ = get(ENV, "MOD", "trait")
body = form == "loop" ? quote
    function passes(tests::Vector{Callable{Tuple{Float64}, Bool}}, x::Float64)
        n = 0
        for t in tests
            t(x) && (n += 1)
        end
        return n
    end
end : quote
    passes(tests::Vector{Callable{Tuple{Float64}, Bool}}, x) = all(t -> t(x), tests)
end
if where_ == "main"
    Core.eval(Main, body)
else
    Core.eval(Main, Expr(:toplevel, :(module Sig
        using TraitWorld
        $(where_ == "trait" ? :(@trait_module) : nothing)
        $body
    end)))
    Core.eval(Main, :(const passes = Sig.passes))
end
r = try
    Base.invokelatest(passes, Callable{Tuple{Float64}, Bool}[x -> 1], 2.0)
catch e
    e
end
println("FORM=$form MOD=$where_ result: ", r isa Exception ? sprint(showerror, r) : repr(r))
