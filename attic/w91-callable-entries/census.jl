# W-91: which specializations present after a workload have a signature type without a hash (compiler §2.9:
# a package image keeps no external code at such a signature, so every session compiles it again).
# Included after the imports (`census_snap()`) and at the end of a session (`census()`, a script); prints the TraitWorld ones each, and counts the rest by module.
#     CENSUS_ALL=1 also lists those of other modules
const _CMT = isdefined(Core, :GlobalMethods) ? Core.GlobalMethods : Core.methodtable
_nohash(@nospecialize(T)) = (u = Base.unwrap_unionall(T); u isa DataType && getfield(u, :hash) == 0)
const _SNAP = Ref{Any}(nothing)
"At the load mark: the CodeInstances that came with the load; `census()` then reports only those made after it."
function census_snap()
    s = Base.IdSet{Any}()
    Base.visit(_CMT) do m
        for mi in Base.specializations(m)
            c = isdefined(mi, :cache) ? mi.cache : nothing
            while c isa Core.CodeInstance; push!(s, c); c = isdefined(c, :next) ? c.next : nothing; end
        end
    end
    _SNAP[] = s; nothing
end
_isnew(c) = _SNAP[] === nothing || !(c in _SNAP[])
function census(io = stdout)
    tw = Any[]; other = Dict{Module,Int}(); otherex = Dict{Module,Any}()
    Base.visit(_CMT) do m
        for mi in Base.specializations(m)
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            ci isa Core.CodeInstance || continue
            _nohash(mi.specTypes) || continue
            anynew = false; c = ci
            while c isa Core.CodeInstance; anynew |= _isnew(c); c = isdefined(c, :next) ? c.next : nothing; end
            anynew || continue
            mod = Base.moduleroot(m.module)
            owners = Any[]; c = ci
            while c isa Core.CodeInstance; push!(owners, c.owner); c = isdefined(c, :next) ? c.next : nothing; end
            if nameof(mod) === :TraitWorld
                push!(tw, (mi.specTypes, owners))
            else
                other[mod] = get(other, mod, 0) + 1
                haskey(otherex, mod) || (otherex[mod] = mi.specTypes)
            end
        end
    end
    println(io, "CENSUS TraitWorld specializations without a hash", _SNAP[] === nothing ? "" : " made after the load mark", ": ", length(tw))
    for (T, o) in sort!(tw; by = x -> string(x[1]))
        println(io, "CENSUS   ", first(string(T), 260), "   owners ", o)
    end
    println(io, "CENSUS other modules: ", sum(values(other); init = 0))
    for (m, n) in sort!(collect(other); by = last, rev = true)
        println(io, "CENSUS   ", rpad(string(m), 24), n, get(ENV, "CENSUS_ALL", "0") == "1" ? "   e.g. " * first(string(otherex[m]), 200) : "")
    end
end
"The CodeInstances made after the load mark of the `Callable` entry and the open result's inference, any hash."
function census_entries(io = stdout)
    TW = Base.root_module(Base.PkgId(Base.UUID("7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"), "TraitWorld"))
    for f in (TW.enter_callable, TW._callable_result)
        n = 0
        for m in methods(f), mi in Base.specializations(m)
            c = isdefined(mi, :cache) ? mi.cache : nothing
            while c isa Core.CodeInstance
                if _isnew(c)
                    n += 1
                    println(io, "ENTRIES   ", nameof(f), " ", first(string(mi.specTypes), 200), " owner ", c.owner, " native ", c.invoke != C_NULL)
                end
                c = isdefined(c, :next) ? c.next : nothing
            end
        end
        println(io, "ENTRIES ", nameof(f), " new CodeInstances: ", n)
    end
end
