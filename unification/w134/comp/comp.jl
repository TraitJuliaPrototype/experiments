# E-358: a session that loads the members in a random order, working after each load.
#     JULIA_LOAD_PATH=<pkgs>/trait|plain:<env with TraitWorld>:@stdlib julia comp.jl trait|plain <seed> [n=20]
const kind = ARGS[1]; const seed = parse(Int, ARGS[2]); const n = length(ARGS) > 2 ? parse(Int, ARGS[3]) : 20
const FACTS = 0x20
const corename = kind == "trait" ? :CompCore : :PCore
const prefix = kind == "trait" ? "CompM" : "PM"
# a permutation from the seed, with no package loaded for it
function perm(n, seed)
    p = collect(1:n); x = UInt64(seed) * 0x9e3779b97f4a7c15 + 1
    for i in n:-1:2
        x = x * 6364136223846793005 + 1442695040888963407
        j = Int((x >> 33) % i) + 1; p[i], p[j] = p[j], p[i]
    end
    p
end
const order = seed == 0 ? collect(1:n) : perm(n, seed)
t0 = @elapsed (const Core_ = Base.require(Main, corename))
const OWN = Set{Symbol}([corename])
function tally()
    res = Tuple{Symbol,Core.CodeInstance}[]
    Base.visit(Core.methodtable) do m
        r = nameof(Base.moduleroot(m.module))
        r in OWN || return
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                ci.max_world == typemax(UInt) && ci.owner === nothing && push!(res, (r, ci))
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    res
end
valid(ci) = ci.max_world == typemax(UInt)
const v = Base.invokelatest(() -> Core_.Shape[])
const mods = Module[]
function work()
    t = Core_.work(v)
    for m in mods; t += m.own(m.make(), 3); end
    t
end
held = tally(); lost_total = 0; made = Int[]; lost = Int[]; times = Float64[]; compiles = Float64[]; loadt = Float64[]
Base.cumulative_compile_timing(true)
for i in order
    name = Symbol(prefix, lpad(i, 2, '0'))
    tl = @elapsed (m = Base.require(Main, name))
    push!(OWN, name); push!(mods, m); Base.invokelatest(push!, v, Base.invokelatest(m.make))   # the membership is of the load's world
    push!(lost, count(x -> !valid(x[2]), held)); filter!(x -> valid(x[2]), held)
    n0 = length(tally())
    c0 = Base.cumulative_compile_time_ns()[1]
    t = @elapsed (global d = Base.invokelatest(work))
    push!(times, 1000t); push!(compiles, (Base.cumulative_compile_time_ns()[1] - c0) / 1e6); push!(loadt, 1000tl)
    global held = tally(); push!(made, length(held) - n0)
end
r(x) = round(x; digits = 1)
final = tally()
println("kind ", kind, " seed ", seed, " | order ", join(order, " "))
println("  instances at the end: ", length(final), " (facts ", count(x -> (x[2].flags & FACTS) != 0, final), "), core ", count(x -> x[1] === corename, final),
        " | lost by a later load, in all: ", sum(lost), " | digest ", d)
println("  lost at each load:        ", join(lost, " "))
println("  compiled by the work:     ", join(made, " "))
println("  work after each load, ms: ", join(r.(times), " "))
println("  of it compile, ms:        ", join(r.(compiles), " "))
println("  load of each member, ms:  ", join(r.(loadt), " "), " | core ", r(1000t0))
t = @elapsed Base.invokelatest(work); println("  the work repeated: ", round(1e6 * t; digits = 1), " µs")
