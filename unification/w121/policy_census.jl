# The CodeInstances of the methods compiled by facts, after a load, by policy (compiler §2.3, C-74):
# a method of policy facts has facts code only, so every plain one is a fault.
#   julia --project=<env> policy_census.jl <Package> [<Package> …]
pkgs = Symbol.(ARGS)
for p in pkgs
    @eval using $p
end
mods = Set{Module}(getfield(Main, p) for p in pkgs)
inmods(m::Module) = m in mods || (parentmodule(m) !== m && inmods(parentmodule(m)))
counts = Dict{Module, Vector{Int}}()     # module => [facts, plain, from an image plain]
examples = Dict{Module, Vector{String}}()
mt = isdefined(Core, :methodtable) ? Core.methodtable : Core.GlobalMethods
Base.visit(mt) do m
    m isa Method || return
    inmods(m.module) || return
    ccall(:jl_method_policy, Cint, (Any,), m) == 1 || return
    c = get!(() -> [0, 0, 0], counts, m.module)
    for mi in Base.specializations(m)
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            if ci.owner === nothing
                fl = getfield(ci, :flags, :monotonic)::UInt8
                if fl & 0x20 != 0
                    c[1] += 1
                else
                    c[2] += 1
                    fl & 0x04 != 0 && (c[3] += 1)
                    ex = get!(() -> String[], examples, m.module)
                    length(ex) < 5 && push!(ex, string(mi.specTypes)[1:min(end, 200)])
                end
            end
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
end
for (m, c) in sort(collect(counts); by = x -> string(x[1]))
    println(rpad(string(m), 40), " facts ", lpad(c[1], 6), "  plain ", lpad(c[2], 5), " (from an image ", c[3], ")")
    for e in get(examples, m, String[])
        println("    plain: ", e)
    end
end
