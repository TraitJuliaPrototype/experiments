# Time Base's test/core.jl one top-level expression at a time, with the live heap after each:
# to find where a build spends more than another. Usage: julia core_by_expr.jl <test/core.jl> <out.tsv>
using Test
file, out = abspath(ARGS[1]), ARGS[2]
src = read(file, String)
ex = Meta.parseall(src; filename = file)
mod = Module(:CoreTests)
Core.eval(mod, :(using Test, Base))
Core.eval(mod, :(eval(x) = Core.eval($mod, x)))
Core.eval(mod, :(include(x) = Base.include($mod, joinpath($(dirname(file)), x))))
io = open(out, "w")
line = 0
t00 = time()
for a in ex.args
    global line
    if a isa LineNumberNode
        line = a.line
        continue
    end
    t0 = time_ns()
    Core.eval(mod, Expr(:toplevel, LineNumberNode(line, Symbol(file)), a))
    dt = (time_ns() - t0) / 1e9
    println(io, line, '\t', round(dt; digits = 4), '\t', Base.gc_live_bytes() >> 20, '\t', Sys.maxrss() >> 20)
end
println(io, "total\t", round(time() - t00; digits = 2), "\t", Base.gc_live_bytes() >> 20, '\t', Sys.maxrss() >> 20)
close(io)
