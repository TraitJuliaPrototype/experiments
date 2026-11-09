# The unmet-instance report: method instances compiled at a signature with an argument no type of the
# world is in (an intersection such as `All{AbstractString, IO}`, compiler §5.4). Such an instance can
# never run, yet it holds edges: an invalidation below it climbs through it to everything that inlined
# or called it (the load hooks of TraitWorld, at depth 35-42, at the goal's load on 7bd8b6e512).
#     julia-unified/julia --startup-file=no [--project=<env>] experiments/unification/audit/unmet_instances.jl [Pkg,…] [n]
# Loads the packages, then lists the instances by function, most first. A report: it asserts nothing.
pkgs = length(ARGS) >= 1 && !isempty(ARGS[1]) ? split(ARGS[1], ',') : String[]
nshow = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 40
for p in pkgs
    Core.eval(Main, :(using $(Symbol(p))))
end
world = Base.get_world_counter()
rootof(m::Module) = (p = parentmodule(m); (p === m || p === Main) ? m : rootof(p))

n = 0; nunmet = 0
byf = Dict{Any,Int}(); bymod = Dict{Module,Int}(); samples = Dict{Any,Any}(); withcode = 0
Base.visit(Core.methodtable) do m
    m isa Method || return
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance || continue
        global n += 1
        Base.has_unmet_intersection(mi.specTypes, world) || continue
        global nunmet += 1
        isdefined(mi, :cache) && (global withcode += 1)
        k = m.name
        byf[k] = get(byf, k, 0) + 1
        bymod[rootof(m.module)] = get(bymod, rootof(m.module), 0) + 1
        haskey(samples, k) || (samples[k] = mi.specTypes)
    end
end
println("# the unmet-instance report: world $world, packages $(isempty(pkgs) ? "none" : join(pkgs, ", "))")
println("method instances: $n; at a signature no type is in: $nunmet ($withcode with code)")
println("by module: ", join(["$k $v" for (k, v) in sort(collect(bymod); by = last, rev = true)], ", "))
for (k, v) in first(sort(collect(byf); by = last, rev = true), nshow)
    println(lpad(v, 6), "  ", k, "   e.g. ", first(string(samples[k]), 150))
end
