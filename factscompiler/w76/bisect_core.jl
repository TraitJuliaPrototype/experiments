# W-76 (F-21): which of core.jl's top-level expressions make issue 47476's case raise in the facts image.
# Evaluates core.jl's first H expressions (its header), then expressions k..j, then the 47476 definitions, and
# calls `vect47476(Type{Type{Type{Int32}}})`; prints RAISES or OK. Every expression's own error is ignored.
#     julia -J <facts sys.so> bisect_core.jl <core.jl> k j      (k, j: indices into the top-level expressions)
using Test
const FILE = abspath(ARGS[1]); k = parse(Int, ARGS[2]); j = parse(Int, ARGS[3])
ex = Meta.parseall(read(FILE, String); filename = FILE)
tops = Any[]; lines = Int[]
let ln = 0
    for a in ex.args
        a isa LineNumberNode ? (ln = a.line) : (push!(tops, a); push!(lines, ln))
    end
end
const H = parse(Int, get(ENV, "W76_H", "5"))     # the header: core.jl's first H expressions
cd(dirname(FILE))
M = Module(:CoreBisect)
Core.eval(M, :(using Test, Random, InteractiveUtils))
Core.eval(M, :(include(x) = Base.include($M, x)))
run(e) = try Core.eval(M, e) catch err end
foreach(run, tops[1:H])
foreach(run, tops[max(k, H + 1):min(j, length(tops))])
Core.eval(M, :(vect47476(::Type{T}) where {T} = T))
r = try Base.invokelatest(Core.eval(M, :vect47476), Type{Type{Type{Int32}}}); "OK" catch err; "RAISES " * first(sprint(showerror, err), 80) end
println("R k=", k, " (line ", lines[min(max(k, 1), end)], ") j=", j, " (line ", lines[min(j, end)], ") ", r, "; tops ", length(tops))
