# W-156 third part (compiler C-112, §6.3, §7.4): a method at `Callable` with its function plain, as the wrapper and
# as a box: the methods the definition made, the results, and the instances with code (their first argument's type).
# From TraitWorld/: julia --project=. <this file>
using TraitWorld
f(x) = 2x
g(x) = x + 1
mapc(h::Callable{Tuple{T}}, c::Vector{T}) where {T} = [h(x) for x in c]
once(h::Callable{Tuple{Int}, Int}, x::Int) = h(x)
for fn in (mapc, once)
    println(fn, ": ", length(methods(fn)), " methods: ", join([string(m.sig) for m in methods(fn)], "; "))
end
insts(fn) = unique([string(mi.specTypes.parameters[2]) for m in methods(fn) for mi in Base.specializations(m)
                    if mi !== nothing && isdefined(mi, :cache)])
for (name, h) in (("plain f", f), ("plain g", g), ("wrapper f", compiled_for(f)), ("wrapper g", compiled_for(g)),
                  ("box f", Dynamic{Callable{Tuple{Int}, Int}}(f)))
    r1 = mapc(h, [1, 2, 3]); r2 = once(h, 3)
    println(rpad(name, 10), " ", r1, " ", r2)
end
println("mapc's instances: ", insts(mapc))
println("once's instances: ", insts(once))
