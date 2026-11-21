# C-157: the same call twice in one session, and from a function. Plain Julia's Core.Callable, no library.
const Callable = Core.Callable
function passes(tests::Vector{Callable{Tuple{Float64}, Bool}}, x::Float64)
    n = 0
    for t in tests
        t(x) && (n += 1)
    end
    return n
end
v = Callable{Tuple{Float64}, Bool}[x -> 1]
show_(r) = r isa Exception ? sprint(showerror, r) : repr(r)
for i in 1:3
    r = try passes(v, 2.0) catch e; e end
    println("call $i: ", show_(r))
end
