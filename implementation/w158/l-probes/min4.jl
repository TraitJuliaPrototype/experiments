# C-157: the exception's fields (which check raised), the loop form and Base's `all` form. Plain Core.Callable, no library.
# ORDER=all_first: the `all` form first.
const Callable = Core.Callable
function passes(tests::Vector{Callable{Tuple{Float64}, Bool}}, x::Float64)
    n = 0
    for t in tests
        t(x) && (n += 1)
    end
    return n
end
passes_all(tests::Vector{Callable{Tuple{Float64}, Bool}}, x) = all(t -> t(x), tests)
v = Callable{Tuple{Float64}, Bool}[x -> 1]
show_(r) = r isa TypeError ? "TypeError(func=$(repr(r.func)), context=$(repr(r.context)), expected=$(r.expected), got=$(repr(r.got)))" :
           r isa Exception ? sprint(showerror, r) : repr(r)
fs = get(ENV, "ORDER", "") == "all_first" ? (passes_all, passes) : (passes, passes_all)
for f in fs
    r = try f(v, 2.0) catch e; e end
    println(rpad(string(f), 12), show_(r))
end
