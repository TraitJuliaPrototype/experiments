include(joinpath(@__DIR__, "h.jl"))
module C48; ns(@nospecialize x) = x; passf(f) = f; end
k48() = sum(C48.ns, Int[])
@wrap w48 k48
check("C48 sum over empty with @nospecialize f", res(k48), P(k48), res(w48))
k48b() = (r = C48.ns.(Int[]); push!(r, 1); r)
@wrap w48b k48b
check("C48b empty broadcast then push!", res(()->typeof(k48b())), res(()->typeof(TraitWorld._facts_call(k48b))))
k48c() = prod(C48.ns, Float64[])
@wrap w48c k48c
check("C48c prod over empty with @nospecialize f", res(k48c), P(k48c), res(w48c))
summary()
