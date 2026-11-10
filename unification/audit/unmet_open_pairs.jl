# The unmet-pair census (C-82, open issue 172; E-341): pairs of one function's methods, neither more
# specific than the other, that meet only at an intersection no type of the world is in, at an open set
# (not a final pair). Before C-82 dispatch's lookup left one of them out of a query that met only that
# intersection, so a call there was static; after it, the call dispatches. The pairs bound where the
# change can make a call dynamic. A report: it asserts nothing.
#
# Usage, from the design repository's root after `source env.sh`, in the environment whose packages to load:
#   julia-unified/julia --startup-file=no --project=<env> experiments/unification/audit/unmet_open_pairs.jl Pkg,Pkg2 [n]
pkgs = length(ARGS) >= 1 && !isempty(ARGS[1]) ? Symbol.(split(ARGS[1], ",")) : Symbol[]
nshow = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 20
for p in pkgs
    @eval using $p
end
world = Base.get_world_counter()
unmet(t) = ccall(:jl_has_unmet_argument, Cint, (Any, UInt), t, world) != 0
final(t) = ccall(:jl_unmet_final_cells, Any, (Any,), t) isa Core.SimpleVector
mentions_set(sig) = ccall(:jl_has_open_set, Cint, (Any,), sig) != 0
byfun = Dict{Any, Vector{Method}}()
Base.visit(Core.methodtable) do m
    m isa Method || return
    mentions_set(m.sig) || return
    sig = Base.unwrap_unionall(m.sig)
    sig isa DataType && length(sig.parameters) >= 1 || return
    push!(get!(byfun, sig.parameters[1], Method[]), m)
end
pairs = Tuple{Method, Method, Any}[]
for (ft, ms) in byfun
    others = Method[]
    Base.visit(Core.methodtable) do m
        m isa Method || return
        sig = Base.unwrap_unionall(m.sig)
        (sig isa DataType && length(sig.parameters) >= 1 && sig.parameters[1] == ft) && push!(others, m)
    end
    for a in ms, b in others
        a === b && continue
        mentions_set(b.sig) && objectid(b) < objectid(a) && continue   # each pair of two methods at sets once
        ti = typeintersect(a.sig, b.sig)
        ti === Union{} && continue
        unmet(ti) || continue
        final(ti) && continue
        (Base.morespecific(a, b) || Base.morespecific(b, a)) && continue
        push!(pairs, (a, b, ti))
    end
end
bymod = Dict{Module, Int}()
for (a, b, _) in pairs
    bymod[a.module] = get(bymod, a.module, 0) + 1
end
println("functions with a method at a set: ", length(byfun))
println("pairs meeting only at an unmet intersection at an open set, neither more specific: ", length(pairs))
for (m, n) in sort(collect(bymod); by = last, rev = true)
    println("  ", rpad(string(m), 40), n)
end
for (a, b, ti) in pairs[1:min(nshow, end)]
    println("  ", a, "\n    vs ", b, "\n    at ", ti)
end
