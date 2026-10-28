# The finalizer-inhibition counter under the facts mode: evaluate test/misc.jl's first k top-level expressions,
# then print the counter (0 expected). Every expression's own error is ignored.
#     julia -J <facts sys.so> bisect_misc.jl <misc.jl> k
using Test
const FILE = abspath(ARGS[1]); k = parse(Int, ARGS[2])
ex = Meta.parseall(read(FILE, String); filename = FILE)
tops = Any[]; lines = Int[]
let ln = 0
    for a in ex.args
        a isa LineNumberNode ? (ln = a.line) : (push!(tops, a); push!(lines, ln))
    end
end
cd(dirname(FILE))
M = Module(:MiscBisect)
Core.eval(M, :(using Test))
Core.eval(M, :(include(x) = Base.include($M, x)))
for e in tops[1:min(k, end)]
    try Core.eval(M, e) catch err end
end
fi = ccall(:jl_gc_get_finalizers_inhibited, Int32, (Ptr{Cvoid},), C_NULL)
println("R k=", k, " (line ", lines[min(k, end)], ") inhibited ", fi, "; tops ", length(tops))
