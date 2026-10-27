# E-193: one session's view of each case. For P<i>.go's facts CodeInstance: the witness (its result, and for the
# dispatch cases the method its fact selects), and the identities: direct origins by version, direct origins by a
# hash of their source, the build ids of the dependency closure, and the candidate index's hits.
#     X_PRELOAD=Y5|SparseArrays julia --project=env_a probe.jl
using TOML, Serialization
# the system image's modules: in every closure (the system image is part of the store's key)
const SYSIMG = Set(string(id.name) for id in keys(Base.loaded_modules))
pre = get(ENV, "X_PRELOAD", "")
isempty(pre) || Base.require(Main, Symbol(pre))
const CASES = 1:6
mods = Dict(i => Base.require(Main, Symbol("P$i")) for i in CASES)
results = Dict(i => Base.invokelatest(getglobal(mods[i], :go)) for i in CASES)

const MANIFEST = TOML.parsefile(joinpath(dirname(Base.active_project()), "Manifest.toml"))["deps"]
deps_of(name) = (e = get(MANIFEST, name, nothing); e === nothing ? String[] :
                 (d = get(e[1], "deps", String[]); d isa Dict ? collect(keys(d)) : d))
function closure(names)
    out = Set{String}(); todo = collect(names)
    while !isempty(todo)
        n = pop!(todo); n in out && continue; push!(out, n); append!(todo, deps_of(n))
    end
    return out
end
loaded = Dict(id.name => (id, m) for (id, m) in Base.loaded_modules)
pkgname(m::Module) = (r = Base.moduleroot(m); r === Base || r === Core ? nothing : string(nameof(r)))
function srchash(name)
    haskey(loaded, name) || return 0
    p = pathof(loaded[name][2]); p === nothing && return 0
    h = UInt(0)
    for (root, _, fs) in walkdir(dirname(dirname(p))), f in sort(fs)
        endswith(f, ".jl") && (h = hash(read(joinpath(root, f)), h))
    end
    return h
end
version(name) = (p = haskey(loaded, name) ? pathof(loaded[name][2]) : nothing;
                 p === nothing ? "-" : TOML.parsefile(joinpath(dirname(dirname(p)), "Project.toml"))["version"])
buildid(name) = haskey(loaded, name) ? string(Base.module_build_id(loaded[name][2]); base = 16) : "-"
typepkgs!(out, @nospecialize(x)) =
    x isa Union ? (typepkgs!(out, x.a); typepkgs!(out, x.b)) :
    x isa UnionAll ? typepkgs!(out, x.body) :
    x isa DataType ? (p = pkgname(x.name.module); p === nothing || push!(out, p); foreach(q -> typepkgs!(out, q), x.parameters)) : nothing
function facts_ci(m::Module)
    meth = only(methods(getglobal(getglobal(m, :Impl), :go)))
    for mi in Base.specializations(meth)
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci isa Core.CodeInstance
            ci.owner === :facts && return ci
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
    return nothing
end
const MODE = get(ENV, "X_MODE", "record")
const FILE = get(ENV, "X_FILE", "logs/recorded.jls")
recorded = MODE == "check" ? deserialize(FILE) : Dict{Int,Any}()
function index_hits(sigs, clos)
    hits = String[]
    for sig in sigs
        sig isa DataType && sig <: Tuple && length(sig.parameters) >= 1 || continue
        ft = sig.parameters[1]
        ft isa DataType && isdefined(ft, :instance) || continue
        for meth in methods(ft.instance)
            p = pkgname(meth.module)
            (p === nothing || p in clos || p in SYSIMG) && continue
            typeintersect(meth.sig, sig) === Union{} || push!(hits, "$(p):$(meth.sig)")
        end
    end
    return unique(hits)
end
for i in CASES
    ci = facts_ci(mods[i])
    direct = Set{String}(["P$i"]); sigs = Any[]
    if ci !== nothing && isdefined(ci, :edges)
        for e in ci.edges
            m = e isa Core.CodeInstance ? (e.def isa Core.MethodInstance ? e.def.def : e.def.def.def) :
                e isa Core.MethodInstance ? e.def : nothing
            if m isa Method
                p = pkgname(m.module); p === nothing || push!(direct, p)
                mi = e isa Core.CodeInstance ? (e.def isa Core.MethodInstance ? e.def : e.def.def) : e
                push!(sigs, mi.specTypes); typepkgs!(direct, mi.specTypes)
            elseif e isa Type
                push!(sigs, e); typepkgs!(direct, e)
            end
        end
    end
    clos = closure(direct)
    # the candidate index: methods of the facts' functions that no image in the closure defined
    hits = String[]
    for sig in sigs
        sig isa DataType && sig <: Tuple && length(sig.parameters) >= 1 || continue
        ft = sig.parameters[1]
        ft isa DataType && isdefined(ft, :instance) || continue
        for meth in methods(ft.instance)
            p = pkgname(meth.module)
            (p === nothing || p in clos || p in SYSIMG) && continue
            typeintersect(meth.sig, sig) === Union{} || push!(hits, "$(p):$(meth.sig)")
        end
    end
    target = ""
    if i in (5, 6)
        f, at = i == 5 ? (getglobal(loaded["X5"][2], :g5), (getglobal(loaded["X5"][2], :T5),)) : (vcat, (Int, Vector{Int}))
        target = string(which(f, at).module)
    end
    ids = Dict(n => buildid(n) for n in clos)
    if MODE == "record"
        recorded[i] = (sigs = sigs, clos = clos, ids = ids, result = results[i], target = target)
    else
        r = recorded[i]
        same_result = r.result == results[i] && r.target == target
        same_ids = all(n -> buildid(n) == r.ids[n], collect(r.clos))
        h = index_hits(r.sigs, r.clos)
        println("K ", i, "\tthe recorded entry against this session: fresh compile ", same_result ? "same" : "differs",
                "; closure build ids ", same_ids ? "same" : "differ", "; index ", isempty(h) ? "no hit" : "hit: " * join(h, ";"),
                "; caught: ", (!same_ids || !isempty(h)) ? "yes" : "no", same_result ? " (nothing to catch)" : "")
    end
    println("C ", i, "\tresult=", repr(results[i]), " target=", target,
            "\tdirect=", join(sort(collect(direct)), ","),
            "\tversions=", join(["$n@$(version(n))" for n in sort(collect(direct))], ","),
            "\tsrc=", string(hash([srchash(n) for n in sort(collect(direct))]); base = 16),
            "\tclosure=", string(hash([buildid(n) for n in sort(collect(clos))]); base = 16),
            "\tindex=", isempty(hits) ? "none" : join(unique(hits), ";"))
end
MODE == "record" && serialize(FILE, recorded)
