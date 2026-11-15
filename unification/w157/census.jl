# W-157 (stage 5, D-8; E-476 onwards): the census of Base's surface below a port's code compiled by facts.
# Built on `../w155/deep.jl` (the deep class, E-416, E-417) and `../w155b/diag/why_not_deep.jl` (the first
# edge that keeps an instance out). The deep class is the G2 bit (compiler §3.2).
#     julia --project=env_forks|env_facts census.jl <csv> [<package>...]
# (a) the share: the own image instances and the own facts instances (image and made by the work) with the bit;
# (b) the culprits: every instance reached below the own code, without the bit, whose own record keeps it out
#     (an edge at a signature that is no fact, a callee named by its MethodInstance alone), not only a callee
#     without the bit; each by method and by kind;
# (c) for each own facts instance outside the class, its cone: the culprits reached from it through instances
#     outside the class. It enters the class when every culprit of its cone is fixed. So a culprit's reach
#     alone is the own instances whose cone is that culprit alone; a group's, those whose cone lies in it;
#     the greedy order of method names, what each buys on top of the ones before;
# (d) with <package>... the loads after it: the own instances ended, of them with the bit (the gate);
# the table of culprits (method, kind, instances, cones it is in, alone) to $CENSUS_TSV if set.
const csv = ARGS[1]; const pk = ARGS[2:end]
include(joinpath(@__DIR__, "census_lib.jl"))
S = census_session(csv)
(; w, d1, image, made, own, factsown, reach, fcache, culprit, nofault, outside, cone, incone) = S
println("# census | project ", basename(dirname(Base.active_project())), " | julia ", Base.GIT_VERSION_INFO.commit_short,
        " | load ", round(Sys.loadavg()[1]; digits = 1))
println("DEEP SHARE | own image instances ", pc(count(bit, image), length(image)), " of ", length(image),
        " | own facts instances ", pc(count(bit, factsown), length(factsown)), " of ", length(factsown),
        " | made by the work ", pc(count(bit, made), length(made)), " of ", length(made))
println("reached through edges ", length(reach), "; without the bit ", count(!bit, reach), "; culprits (a fault of their own) ",
        count(ci -> culprit[ci] !== :cycle_or_unset, keys(culprit)), "; without the bit, no fault and every callee with it ", length(nofault))
let rf = IdSet{Core.CodeInstance}(), st = Core.CodeInstance[factsown...]
    while !isempty(st); ci = pop!(st); ci in rf && continue; push!(rf, ci); for c in succ(ci); c in rf || push!(st, c); end; end
    below = [ci for ci in rf if !(rootof(ci) in CORE8)]
    println("below the own facts instances, outside the own modules: ", length(below), "; outside the class ", count(!bit, below),
            " (the facts copies P3's demand rule would make); of them culprits ", count(ci -> haskey(culprit, ci), below))
end
println("own facts instances outside the class ", length(outside), "; culprits in a cone, median ",
        isempty(outside) ? 0 : sort(length.(values(cone)))[max(1, end ÷ 2)], ", most ", isempty(outside) ? 0 : maximum(length.(values(cone))))
# (b, c) by method name and by kind
bykey(f) = (d = Dict{Any,Vector{Core.CodeInstance}}(); for y in keys(culprit); push!(get!(d, f(y), Core.CodeInstance[]), y); end; d)
function reachof(group::IdSet)   # own facts instances whose cone lies in the group
    count(x -> all(y -> y in group, cone[x]), outside)
end
kinds = bykey(y -> culprit[y]); names_ = bykey(mname)
println("\n## by kind: culprit instances, method names, own facts instances whose cone holds one, whose cone lies in the kind (what fixing the kind buys)")
krows = sort([(k, v) for (k, v) in kinds]; by = kv -> -reachof(IdSet{Any}(kv[2])))
for (k, v) in krows
    s = IdSet{Any}(v)
    println(rpad(string(k), 16), lpad(length(v), 6), " instances ", lpad(length(unique(mname.(v))), 4), " names | in a cone ",
            lpad(count(x -> any(y -> y in s, cone[x]), outside), 5), " | the kind alone ", lpad(reachof(s), 5))
end
println("\n## the kinds together, greedy (what each buys on top of the ones before): own facts instances in the class (of ", length(factsown), ")")
acc = IdSet{Any}(); base0 = count(bit, factsown); left = Dict(krows)
while !isempty(left)
    best = nothing; bestn = -1
    for (k, v) in left
        s2 = IdSet{Any}(acc); foreach(y -> push!(s2, y), v); n = reachof(s2); n > bestn && (bestn = n; best = k)
    end
    foreach(y -> push!(acc, y), left[best]); delete!(left, best)
    println("  + ", rpad(string(best), 16), pc(base0 + bestn, length(factsown)))
end
# by method name: alone, and the greedy order
println("\n## by method name (top 40 by the cones they are in): instances, kind, in a cone, the name alone")
nrows = sort([(k, v, count(x -> any(y -> mname(y) == k, cone[x]), outside)) for (k, v) in names_]; by = r -> -r[3])
for (k, v, n) in nrows[1:min(end, 40)]
    ks = unique([culprit[y] for y in v])
    println(lpad(n, 6), "  ", rpad(k, 44), lpad(length(v), 5), " inst  ", rpad(join(string.(ks), ","), 26), " alone ", reachof(IdSet{Any}(v)))
end
println("\n## greedy: the method name that buys most on top of the ones before (own facts instances in the class)")
chosen = IdSet{Any}(); cur = base0; println("  start ", pc(cur, length(factsown)))
cands = [(k, v) for (k, v, n) in nrows if n > 0]
for step in 1:25
    best = nothing; bestn = -1
    for (k, v) in cands
        any(y -> y in chosen, v) && continue
        s = IdSet{Any}(chosen); foreach(y -> push!(s, y), v)
        n = reachof(s); n > bestn && (bestn = n; best = (k, v))
    end
    best === nothing && break
    foreach(y -> push!(chosen, y), best[2])
    println("  ", lpad(step, 2), ". + ", rpad(best[1], 44), " ", rpad(string(unique([culprit[y] for y in best[2]])), 30), pc(base0 + bestn, length(factsown)))
end
# the culprits most own facts instances rest on, with their own faults
println("\n## the culprit instances most own facts instances rest on")
for (y, n) in sort(collect(incone); by = last, rev = true)[1:min(end, 30)]
    fs = get(fcache, y, Fault[])
    println(lpad(n, 6), "  ", rpad(string(culprit[y]), 15), first(string(y.def.specTypes), 130))
    for f in fs[1:min(end, 2)]; println("            ", f.kind, ": ", first(string(f.sig), 140)); end
end
# the rule's view: the faults by the function called (a culprit counts once per function), and what fixing
# every fault at that function buys alone (the cones whose culprits all have only such faults)
function fcalled(f::Fault)
    f.kind === :mi && return "(by instance)"
    g = fname(f.sig)
    if g isa DataType && g.name === Type.body.name
        p = g.parameters[1]
        u = p isa Type ? Base.unwrap_unionall(p) : p
        return string("constructor ", u isa DataType ? nameof(u) : string(p))
    end
    fn = fnname(g)
    return fn === nothing ? string(g) : string(parentmodule(g.instance), ".", fn)
end
byf = Dict{String,Vector{Core.CodeInstance}}()
for (y, k) in culprit; k === :cycle_or_unset && continue; for fn in unique(fcalled.(fcache[y])); push!(get!(byf, fn, Core.CodeInstance[]), y); end; end
fixed_by(fns::Set{String}) = IdSet{Any}([y for (y, k) in culprit if k !== :cycle_or_unset && all(f -> fcalled(f) in fns, fcache[y])])
println("\n## faults by the function called (top 40 by the cones of its culprits): culprits with such a fault, in a cone, the fault's function alone")
frows = sort([(k, v, count(x -> any(y -> y in IdSet{Any}(v), cone[x]), outside)) for (k, v) in byf]; by = r -> -r[3])
for (k, v, n) in frows[1:min(end, 40)]
    println(lpad(n, 6), "  ", rpad(first(k, 60), 62), lpad(length(v), 5), " culprits  alone ", reachof(fixed_by(Set([k]))))
end
# what ownership by declaration would buy (facts §3, owner-only functions): a fault at a call of a function of
# Base or Core with no method by a package in the session, (a) neither exported nor public, (b) any
pkgmeth = Set{Any}()
Base.visit(Core.methodtable) do m
    r = nameof(Base.moduleroot(m.module)); r in (:Base, :Core) && return
    ft = Base.unwrap_unionall(m.sig); ft isa DataType && length(ft.parameters) >= 1 && push!(pkgmeth, ft.parameters[1])
end
function ownable(f::Fault, internal::Bool)
    f.kind === :mi && return false
    g = fname(f.sig); fn = fnname(g); fn === nothing && return false
    mod = parentmodule(g.instance); nameof(Base.moduleroot(mod)) in (:Base, :Core) || return false
    g in pkgmeth && return false
    internal || return true
    return !(Base.isexported(mod, fn) || Base.ispublic(mod, fn))
end
for (lab, internal) in (("internal (neither exported nor public)", true), ("any", false))
    fx = IdSet{Any}([y for (y, k) in culprit if k !== :cycle_or_unset && all(f -> ownable(f, internal), fcache[y])])
    println("what-if: Base's and Core's functions owner-only by declaration, ", lab, ", no package method in the session: ",
            length(fx), " culprits resolved; own facts instances in the class ", pc(base0 + reachof(fx), length(factsown)))
end
# open issue 195 (a): the callees named by instance alone whose code is in the class now
mi_fixable = count(x -> !isempty(cone[x]) && all(y -> culprit[y] === :by_instance && all(f -> f.kind !== :mi || any(bit, micode(f.sig)), fcache[y]), cone[x]), outside)
println("\nown facts instances kept out only by callees named by instance alone, whose code has the bit now: ", mi_fixable)
if haskey(ENV, "CENSUS_TSV")
    open(ENV["CENSUS_TSV"], "w") do io
        println(io, "method\tkind\tinstances\tin_cone\talone")
        for (k, v, n) in nrows; println(io, k, "\t", join(unique(string.([culprit[y] for y in v])), ","), "\t", length(v), "\t", n, "\t", reachof(IdSet{Any}(v))); end
    end
end
# (d) the loads
if !isempty(pk)
    tl = @elapsed for p in pk; Core.eval(Main, Meta.parse("using $p")); end
    println("\nthe loads: ", round(tl; digits = 1), " s")
    for (name, set) in (("image", image), ("made", made))
        l = [ci for ci in set if !valid(ci)]
        println(name, ": the loads end ", length(l), " of ", length(set), " | facts ", count(isfacts, l), " | with the bit ", count(bit, l))
        for ci in l; bit(ci) && println("   ENDED WITH THE BIT: ", first(string(ci.def.specTypes), 160)); end
    end
    below = [ci for ci in reach if !(rootof(ci) in CORE8)]
    println("below, outside the own modules: ", length(below), " | ended ", count(!valid, below), " | of them with the bit ", count(ci -> !valid(ci) && bit(ci), below))
    d2 = Base.invokelatest(w); println("digest ", d1, d1 == d2 ? " (equal after)" : " DIFFERS")
end
