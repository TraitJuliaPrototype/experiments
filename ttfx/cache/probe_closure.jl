# E-194 (W-66): the facts-keyed cache at scale. For the CodeInstances a session made: time per owner (inference self
# time and code generation, from the CodeInstances' own fields); for each facts entry naming no session type: its
# dependency closure (packages reached through its edges, transitively through callee CodeInstances, its signature's
# types and their supertypes, bindings and folds, closed under the manifest's dependencies), whether it reaches code
# of another owner, and the candidate index (methods of its facts' functions that neither its closure nor the system
# image defined, intersecting a fact).
#     WL_SHAPE=perturbed julia --project=<env> cache/probe_closure.jl workload.jl out/png
const NEW = Any[]
ccall(:jl_set_newly_inferred, Cvoid, (Any,), NEW)
const SYSIMG = Set(string(id.name) for id in keys(Base.loaded_modules))
const _SCRIPT, _OUT = ARGS[1], ARGS[2]
empty!(ARGS); push!(ARGS, _OUT)
include(joinpath(@__DIR__, "..", _SCRIPT))
ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)

using TOML
let
    manifest = TOML.parsefile(joinpath(dirname(Base.active_project()), "Manifest.toml"))["deps"]
    deps_of(n) = (e = get(manifest, n, nothing); e === nothing ? String[] : (d = get(e[1], "deps", String[]); d isa Dict ? collect(keys(d)) : d))
    # an extension's dependencies: its parent and triggers (from the loaded extensions)
    extdeps = Dict(string(id.name) => [string(p.name) for p in ps] for (id, ps) in Base.EXT_PRIMED)
    mods = IdDict{Module,String}()
    for (id, m) in Base.loaded_modules; id.name == "Main" || (mods[m] = id.name); end
    pkgname(m::Module) = (r = Base.moduleroot(m); r === Base || r === Core ? nothing : get(mods, r, "session"))
    function tclose(names)
        out = Set{String}(); todo = collect(names)
        while !isempty(todo)
            n = pop!(todo); n in out && continue; push!(out, n)
            append!(todo, deps_of(n)); append!(todo, get(extdeps, n, String[]))
        end
        out
    end
    function typepkgs!(out, @nospecialize(x))
        if x isa Union; typepkgs!(out, x.a); typepkgs!(out, x.b)
        elseif x isa UnionAll; typepkgs!(out, x.var.ub); typepkgs!(out, x.body)
        elseif x isa TypeVar; typepkgs!(out, x.ub)
        elseif x isa Core.TypeofVararg; isdefined(x, :T) && typepkgs!(out, x.T)
        elseif x isa DataType
            t = x
            while true                                   # the type and its supertypes
                p = pkgname(t.name.module); p === nothing || push!(out, p)
                t === Any && break
                t = supertype(t)
            end
            foreach(q -> typepkgs!(out, q), x.parameters)
        elseif !(x isa Union{Symbol,Number,Char,Nothing,String,Tuple}); typepkgs!(out, typeof(x))
        end
        out
    end
    ciof(e) = e isa Core.CodeInstance ? e : nothing
    mi_of(ci::Core.CodeInstance) = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
    f16(x) = Float64(reinterpret(Float16, x))
    # time per owner
    tinf = Dict{Any,Float64}(); tcg = Dict{Any,Float64}(); cnt = Dict{Any,Int}()
    for ci in NEW
        ci isa Core.CodeInstance || continue
        o = ci.owner
        tinf[o] = get(tinf, o, 0.0) + f16(ci.time_infer_self)
        tcg[o] = get(tcg, o, 0.0) + f16(ci.time_compile)
        cnt[o] = get(cnt, o, 0) + 1
    end
    println("Z CodeInstances made, by owner (count, inference self-time s, code generation s):")
    for o in keys(cnt)
        println("Z   ", rpad(string(o), 26), lpad(cnt[o], 7), "  ", round(tinf[o]; digits = 2), "  ", round(tcg[o]; digits = 2))
    end
    # facts entries
    entries = []; nsession = 0; nother = 0
    for ci in NEW
        ci isa Core.CodeInstance && ci.owner === :facts || continue
        mi = mi_of(ci); mi.def isa Method || continue
        direct = Set{String}(); sigs = Any[]; other = false
        p = pkgname(mi.def.module); p === nothing || push!(direct, p)
        typepkgs!(direct, mi.specTypes)
        seen = Base.IdSet{Core.CodeInstance}(); todo = Core.CodeInstance[ci]
        while !isempty(todo)
            c = pop!(todo); c in seen && continue; push!(seen, c)
            c.owner === :facts || (other = true)
            isdefined(c, :edges) || continue
            for e in c.edges
                if e isa Core.CodeInstance
                    push!(todo, e); m = mi_of(e).def
                    m isa Method && (q = pkgname(m.module); q === nothing || push!(direct, q))
                    c === ci && push!(sigs, mi_of(e).specTypes)
                elseif e isa Core.MethodInstance
                    m = e.def; m isa Method && (q = pkgname(m.module); q === nothing || push!(direct, q))
                    typepkgs!(direct, e.specTypes); c === ci && push!(sigs, e.specTypes)
                elseif e isa Type
                    typepkgs!(direct, e); c === ci && push!(sigs, e)
                elseif e isa Core.Binding
                    q = pkgname(e.globalref.mod); q === nothing || push!(direct, q)
                elseif e isa Base.Compiler.FoldRecord
                    for fld in fieldnames(typeof(e))
                        v = getfield(e, fld); v isa Module && (q = pkgname(v); q === nothing || push!(direct, q))
                    end
                end
            end
        end
        if "session" in direct
            nsession += 1; continue
        end
        other && (nother += 1)
        clos = tclose(direct)
        hits = 0
        for sig in sigs
            sig isa DataType && sig <: Tuple && length(sig.parameters) >= 1 || continue
            ft = sig.parameters[1]
            ft isa DataType && isdefined(ft, :instance) || continue
            for meth in methods(ft.instance)
                q = pkgname(meth.module)
                (q === nothing || q in clos || q in SYSIMG) && continue
                typeintersect(meth.sig, sig) === Union{} || (hits += 1)
            end
        end
        push!(entries, (clos = clos, other = other, hits = hits, t = f16(ci.time_infer_self) + f16(ci.time_compile)))
    end
    n = length(entries)
    println("Z facts entries: ", n, " cacheable; ", nsession, " naming the session; ", nother, " of the cacheable reach another owner's code")
    println("Z closure size (packages): mean ", round(sum(length(e.clos) for e in entries; init = 0) / max(n, 1); digits = 1),
            ", max ", maximum((length(e.clos) for e in entries); init = 0), "; entries with an empty closure (Base, Core, the system image): ",
            count(e -> isempty(setdiff(e.clos, SYSIMG)), entries))
    println("Z entries hitting a candidate: ", count(e -> e.hits > 0, entries), " (", sum(e.hits for e in entries; init = 0), " hits)")
    pk = Dict{String,Int}()
    for e in entries, p in e.clos; p in SYSIMG || (pk[p] = get(pk, p, 0) + 1); end
    println("Z a change of each package (it and its dependents rebuilt) invalidates (share of the cacheable entries), the 15 largest:")
    for (p, k) in sort!(collect(pk); by = last, rev = true)[1:min(end, 15)]
        println("Z   ", rpad(p, 36), lpad(k, 7), "  ", round(100k / max(n, 1); digits = 1), "%")
    end
end
