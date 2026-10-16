# E1 and E2 on the demonstrators, stock Julia 1.13.2, with the D stack loaded first.
#  - the closure: every CodeInstance reachable through edges from the code of the trait modules
#    (ODECore, PlotCore) after their workloads ran;
#  - E2: at each concrete fact (an edge to a MethodInstance with a concrete signature), does
#    dispatch currently select a pirate (a method whose package owns neither the function nor a type)?
#  - E1: the abstract facts (edges at non-concrete signatures, which R would turn into run-time
#    dispatch), and which of them sit in code that is hot (sampled by the profiler while the
#    demonstrators run their inner work).
using CSV, DataFrames, CairoMakie
using TraitDifferentialEquations, TraitMakie, TraitWorld
const TDE = TraitDifferentialEquations
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
prob = ODEProblem(lorenz!, [1.0, 0.0, 0.0], (0.0, 20.0), [10.0, 28.0, 8 / 3])
cb = DiscreteCallback((u, t, i) -> t > 5.0 && t < 5.1, i -> (i.u[1] += 0.1; nothing))
work() = (TDE.solve(prob, TDE.Tsit5(); callback = cb); TDE.solve(prob, TDE.Rodas5());
          xs = collect(range(0.0, 10.0; length = 2000)); f = TraitMakie.lines(xs, sin.(xs); title = "x");
          TraitMakie.scatter!(f, xs, cos.(xs); color = :red); TraitMakie.save(joinpath(ENV["TMPDIR"], "e12.png"), f))
work()

isTW(m::Module) = (r = m; while true; isdefined(r, :__trait_module__) && return true; p = parentmodule(r); p === r && return false; r = p; end)
roots = Core.CodeInstance[]
for M in (TDE.ODECore, TraitMakie.PlotCore), n in names(M; all = true)
    isdefined(M, n) || continue
    x = getglobal(M, n)
    x isa Function || continue
    parentmodule(x) === M || continue
    for m in methods(x), mi in Base.specializations(m)
        isdefined(mi, :cache) || continue
        ci = mi.cache
        ci.max_world == typemax(UInt) && push!(roots, ci)
    end
end
# the operations' implementations and conformance methods live in TraitWorld functions with methods from these modules
for f in (TraitWorld.conformance, TraitWorld.op_default), m in methods(f)
    isTW(m.module) || continue
    for mi in Base.specializations(m)
        isdefined(mi, :cache) && mi.cache.max_world == typemax(UInt) && push!(roots, mi.cache)
    end
end
seen = Base.IdSet{Any}(); stack = copy(roots)
concrete = Dict{Any,Any}()      # specTypes => (method, holder)
abstract = Any[]                # (holder CI, signature, n methods)
latest(mi) = (isdefined(mi, :cache) ? mi.cache : nothing)
while !isempty(stack)
    ci = pop!(stack)
    ci in seen && continue
    push!(seen, ci)
    es = ci.edges
    es isa Core.SimpleVector || continue
    j = 1
    while j <= length(es)
        e = es[j]
        if e isa Int
            sig = es[j+1]
            push!(abstract, (ci, sig, e))
            j += 2 + abs(e)
            continue
        elseif e isa Core.CodeInstance || e isa Core.MethodInstance
            mi = e isa Core.CodeInstance ? Base.get_ci_mi(e) : e
            st = mi.specTypes
            if isconcretetype(st) || (st isa DataType && all(p -> isconcretetype(p) || (p isa DataType && p <: Type), st.parameters))
                concrete[st] = (mi.def, ci)
            else
                push!(abstract, (ci, st, 0))
            end
            c2 = e isa Core.CodeInstance ? e : latest(mi)
            c2 === nothing || push!(stack, c2)
        elseif e isa Type
            j += 2; continue          # an invoke edge: (signature, method)
        end
        j += 1
    end
end
println("closure: ", length(seen), " CodeInstances; concrete facts: ", length(concrete), "; abstract facts: ", length(abstract))

# E2: winning pirates at concrete facts
pir = Any[]
for (st, (m, holder)) in concrete
    sel = Base._which(st; raise = false)
    sel === nothing && continue
    mm = sel.method
    TraitWorld.owned_method(mm) && continue
    r = Base.moduleroot(mm.module)
    nameof(r) in (:Base, :Core, :LinearAlgebra, :Random, :Printf, :Statistics, :SparseArrays) && continue
    push!(pir, (st, mm))
end
println("E2: concrete facts where dispatch now selects a pirate from outside Julia: ", length(pir))
for (st, mm) in first(pir, 15); println("   ", first(string(st), 120), "  ->  ", mm.module, " ", mm.file, ":", mm.line); end

# E1: abstract facts, and which are in hot code
using Profile
Profile.clear(); Profile.init(n = 10^7, delay = 0.0005)
@profile for _ in 1:30; work(); end
data, lidict = Profile.retrieve()
hot = Dict{Any,Int}()             # method => samples
for ip in data
    ip == 0 && continue
    for fr in get(lidict, ip, Base.StackTraces.StackFrame[])
        fr.linfo isa Core.MethodInstance || (fr.linfo isa Core.CodeInstance) || continue
        mi = fr.linfo isa Core.CodeInstance ? Base.get_ci_mi(fr.linfo) : fr.linfo
        hot[mi.def] = get(hot, mi.def, 0) + 1
    end
end
total = count(!=(0), data)
byholder = Dict{Any,Vector{Any}}()
for (ci, sig, n) in abstract
    push!(get!(byholder, Base.get_ci_mi(ci).def, Any[]), sig)
end
rows = sort([(get(hot, m, 0), m, unique(sigs)) for (m, sigs) in byholder]; by = first, rev = true)
println("E1: methods in the closure holding abstract facts: ", length(rows), "; of them sampled at all: ", count(r -> r[1] > 0, rows), " (", total, " samples in all)")
for (s, m, sigs) in first(rows, 25)
    println("  ", lpad(s, 6), " samples  ", m.module, ".", m.name, "  — ", length(sigs), " abstract: ", first(join(map(x -> first(string(x), 70), first(sigs, 2)), " | "), 160))
end
