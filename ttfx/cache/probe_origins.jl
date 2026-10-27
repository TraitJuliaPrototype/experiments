# E-188 (W-66 step 1): the origins of a session's facts code. Runs a workload script with the runtime's
# newly-inferred list switched on from the start, then, for every CodeInstance of owner :facts the session made,
# its origins: the packages owning its method, the types in its signature, and its edges' callees and signatures.
#     WL_D=trait WL_SHAPE=perturbed julia --project=env_d cache/probe_origins.jl workload_d.jl out/png
const NEW = Any[]
ccall(:jl_set_newly_inferred, Cvoid, (Any,), NEW)
const _SCRIPT, _OUT = ARGS[1], ARGS[2]
empty!(ARGS); push!(ARGS, _OUT)
include(joinpath(@__DIR__, "..", _SCRIPT))
ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)

let
    mods = IdDict{Module,Base.PkgId}()
    for (id, m) in Base.loaded_modules
        id.name == "Main" || (mods[m] = id)
    end
    pkgname(m::Module) = (id = get(mods, Base.moduleroot(m), nothing); id === nothing ? :session : Symbol(id.name))
    # the packages a type names; :session for a module that no image holds
    function typepkgs!(out, @nospecialize(x))
        if x isa Union
            typepkgs!(out, x.a); typepkgs!(out, x.b)
        elseif x isa UnionAll
            typepkgs!(out, x.var.ub); typepkgs!(out, x.body)
        elseif x isa TypeVar
            typepkgs!(out, x.ub)
        elseif x isa Core.TypeofVararg
            isdefined(x, :T) && typepkgs!(out, x.T)
        elseif x isa DataType
            push!(out, pkgname(x.name.module))
            for p in x.parameters; typepkgs!(out, p); end
        elseif !(x isa Union{Symbol,Number,Char,Nothing,String,Tuple})
            typepkgs!(out, typeof(x))
        end
        return out
    end
    methpkg(e) = (m = e isa Core.CodeInstance ? (e.def isa Core.MethodInstance ? e.def.def : e.def.def.def) :
                      e isa Core.MethodInstance ? e.def : e isa Method ? e : nothing;
                  m isa Method ? pkgname(m.module) : nothing)
    entries = Vector{Set{Symbol}}()
    nsession = 0; nfacts = 0
    for ci in NEW
        ci isa Core.CodeInstance && ci.owner === :facts || continue
        nfacts += 1
        mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
        mi.def isa Method || continue
        o = Set{Symbol}([pkgname(mi.def.module)])
        typepkgs!(o, mi.specTypes)
        if isdefined(ci, :edges)
            for e in ci.edges
                p = methpkg(e)
                p === nothing || push!(o, p)
                e isa Type && typepkgs!(o, e)
            end
        end
        if :session in o
            nsession += 1
            continue
        end
        delete!(o, :Core); delete!(o, :Base)
        push!(entries, o)
    end
    n = length(entries)
    byowner = Dict{Any,Int}(); bymod = Dict{Tuple{Any,Symbol},Int}()
    for ci in NEW
        ci isa Core.CodeInstance || continue
        byowner[ci.owner] = get(byowner, ci.owner, 0) + 1
        mi = ci.def isa Core.MethodInstance ? ci.def : ci.def.def
        mi.def isa Method || continue
        k = (ci.owner, pkgname(mi.def.module)); bymod[k] = get(bymod, k, 0) + 1
    end
    println("O all CodeInstances made in the session, by owner: ", byowner)
    for (k, v) in sort!(collect(bymod); by = last, rev = true)[1:min(end, 14)]
        println("O   ", rpad(string(k[1]), 8), rpad(k[2], 30), lpad(v, 6))
    end
    println("O facts CodeInstances made in the session: ", nfacts, "; naming the session's own code or types: ", nsession, "; cacheable: ", n)
    sizes = map(length, entries)
    println("O origins per entry (packages besides Base and Core): mean ", round(sum(sizes) / max(n, 1); digits = 2),
            ", max ", maximum(sizes; init = 0), ", none (Base and Core only): ", count(==(0), sizes))
    println("O distinct origin sets: ", length(unique(entries)))
    pk = Dict{Symbol,Int}()
    for o in entries, p in o; pk[p] = get(pk, p, 0) + 1; end
    println("O loaded packages (besides Main): ", length(mods), "; packages that are an origin: ", length(pk))
    println("O a new version of each package invalidates (share of the cacheable entries; an environment key: all):")
    for (p, k) in sort!(collect(pk); by = last, rev = true)
        println("O   ", rpad(p, 32), lpad(k, 6), "  ", round(100k / n; digits = 1), "%")
    end
end
