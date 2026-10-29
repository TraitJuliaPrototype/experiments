# E-238 (W-92): which plain code the forks' session compiles again after the loads invalidated it, and who enters it.
# Included into the REPL session by census.sh. The invalidation log is started in `-e` before the REPL
# (`_INVLOG`), so it covers the REPL's start ("repl"), the imports ("load") and the session ("session").
#     _loadmark!()      at the imports' mark: the world, the log's length and the CodeInstances then
#                       (`_NS`, the log's length at the session's first mark, is set by census.sh)
#     _census(path)     at the end: one line per invalidated MethodInstance, with its cause (the method inserted),
#                       its depth in the tree (0: calls the changed signature itself; -1: the method's own
#                       instance replaced), the phase (load or session), its code now by owner (created after the
#                       load mark or not), and for code compiled again the callers that hold an edge to it
const _W0 = Ref{UInt}(0); const _N0 = Ref{Int}(0); const _OLD = Ref{Any}(nothing)
const _MT = isdefined(Core, :GlobalMethods) ? Core.GlobalMethods : Core.methodtable
function _allcis()
    s = Base.IdSet{Any}()
    Base.visit(_MT) do m
        for mi in Base.specializations(m); for ci in _cis(mi); push!(s, ci); end; end
    end
    s
end
_loadmark!() = (_W0[] = Base.get_world_counter(); _N0[] = length(Main._INVLOG); _OLD[] = _allcis(); nothing)
_mi(x) = x isa Core.CodeInstance ? (x.def isa Core.MethodInstance ? x.def : x.def.def) : x
function _cis(mi::Core.MethodInstance)
    out = Core.CodeInstance[]
    ci = isdefined(mi, :cache) ? mi.cache : nothing
    while ci isa Core.CodeInstance
        push!(out, ci); ci = isdefined(ci, :next) ? ci.next : nothing
    end
    out
end
_own(o) = o === nothing ? "plain" : string(o)
_modroot(mi) = mi.def isa Method ? Base.moduleroot(mi.def.module) : Core
function _callers(mi::Core.MethodInstance)
    isdefined(mi, :backedges) || return "none"
    d = Dict{String,Int}()
    for b in mi.backedges
        b isa Core.CodeInstance || continue
        b.max_world == typemax(UInt) || continue
        cm = _mi(b)
        k = string(_own(b.owner), ":", _modroot(cm), ".", cm.def isa Method ? cm.def.name : :toplevel)
        d[k] = get(d, k, 0) + 1
    end
    isempty(d) ? "none" : join(("$k×$v" for (k, v) in sort!(collect(d); by = last, rev = true)[1:min(end, 4)]), ", ")
end
function _census(path)
    invs = Main._INVLOG
    ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
    rows = Any[]; pending = Any[]
    for i in eachindex(invs)
        x = invs[i]
        if x isa Core.MethodInstance || x isa Core.CodeInstance
            d = (i < length(invs) && invs[i+1] isa Int32) ? Int(invs[i+1]) : -1
            push!(pending, (i, _mi(x), d))
        elseif x isa Method
            for (j, m, d) in pending; push!(rows, (j, m, d, x)); end
            empty!(pending)
        end
    end
    for (j, m, d) in pending; push!(rows, (j, m, d, nothing)); end
    seen = Base.IdSet{Any}()
    nrec = Dict{String,Int}(); ninv = Dict{String,Int}()
    open(path, "w") do io
        println(io, "# world at the load mark ", _W0[], "; log entries ", length(invs), " (", Main._NS, " by the session's first mark, ", _N0[], " by the load mark)")
        for (j, mi, d, cause) in rows
            mi in seen && continue; push!(seen, mi)
            phase = j <= Main._NS ? "repl" : j <= _N0[] ? "load" : "session"
            cis = _cis(mi)
            new = [ci for ci in cis if !(ci in _OLD[]) && ci.max_world == typemax(UInt)]
            newp = count(ci -> ci.owner === nothing, new)
            newf = count(ci -> ci.owner === :facts, new)
            validold = count(ci -> ci in _OLD[] && ci.max_world == typemax(UInt), cis)
            cm = cause === nothing ? "?" : string(parentmodule(cause), ".", cause.name)
            k = string(phase, " ", cm)
            ninv[k] = get(ninv, k, 0) + 1
            (newp + newf > 0) && (nrec[k] = get(nrec, k, 0) + 1)
            println(io, "INV ", phase, " d", d, " new_plain ", newp, " new_facts ", newf, " valid_old ", validold,
                    " | ", cm, " | ", _modroot(mi), " | ", mi.specTypes,
                    newp + newf > 0 ? " | callers " * _callers(mi) : "")
        end
        println(io, "# by cause: invalidated (compiled again in the session)")
        for (k, v) in sort!(collect(ninv); by = last, rev = true)
            println(io, "SUM ", rpad(k, 60), lpad(v, 6), lpad(get(nrec, k, 0), 6))
        end
        println(io, "# total invalidated ", length(seen), "; compiled again after the load mark ", sum(values(nrec); init = 0))
    end
    nothing
end

# ---- the image code rejected at load (Compiler's own log, on from `-e`: `Base.Compiler.ReinferUtils.debug_method_invalidation(true)`)
# entries: (edge, "insert_backedges_callee", codeinst, matches), (codeinst, "verify_methods", cause),
#          (method, "method_globalref", codeinst, nothing)
function _rejections()
    log = Base.Compiler.ReinferUtils._jl_debug_method_invalidation[]
    log === nothing && return Dict{Any,Any}()
    direct = Base.IdDict{Any,Any}(); via = Base.IdDict{Any,Any}()
    i = 1
    while i <= length(log)
        x = log[i]
        if x isa String
            if x == "insert_backedges_callee"
                ci = log[i+1]; ms = log[i+2]
                direct[ci] = (log[i-1], ms isa Vector ? ms : Any[]); i += 3; continue
            elseif x == "verify_methods"
                via[log[i-1]] = log[i+1]; i += 2; continue
            elseif x == "method_globalref"
                direct[log[i+1]] = (log[i-1], Any[]); i += 3; continue
            end
        end
        i += 1
    end
    cause = Base.IdDict{Any,Any}()
    root(ci, n = 0) = haskey(direct, ci) ? direct[ci] : (haskey(via, ci) && n < 1000 ? root(via[ci], n + 1) : nothing)
    for ci in Iterators.flatten((keys(direct), keys(via)))
        cause[ci] = root(ci)
    end
    cause
end
_causestr(c) = c === nothing ? "?" : begin
    edge, ms = c
    mods = unique(string(parentmodule(m), ".", m.name) for m in ms if m isa Method)
    isempty(mods) ? "edge " * first(sprint(show, edge), 100) : join(mods, ",")
end

# ---- the trace's roots between the load mark and the end mark (the session's steps), each classified
function _tracemodule()
    M = Module(:_TM)
    for m in Iterators.flatten((values(Base.loaded_modules), (Main, Core, Base)))
        n = nameof(m)
        isdefined(M, n) || Core.eval(M, :(const $n = $m))
    end
    M
end
function _mi_of(M, s)
    T = try Core.eval(M, Meta.parse(s)) catch; return nothing end
    T isa Type || return nothing
    m = try Base._which(T; raise = false) catch; nothing end
    m === nothing && return nothing
    try Base.Compiler.specialize_method(m) catch; nothing end
end
function _roots(tracepath, out, off0, off1 = typemax(Int))
    rej = _rejections()
    invset = Base.IdDict{Any,Any}()
    pending = Any[]
    for x in Main._INVLOG
        if x isa Core.MethodInstance || x isa Core.CodeInstance; push!(pending, _mi(x))
        elseif x isa Method; for m in pending; invset[m] = x; end; empty!(pending); end
    end
    M = _tracemodule()
    txt = read(tracepath, String)
    rows = Any[]
    for l in eachline(IOBuffer(txt[off0+1:min(end, off1)]))
        m = match(r"^#= *([0-9.]+) ms =# precompile\((.*)\)( # recompile)?$", l)
        m === nothing && continue
        ms = parse(Float64, m[1]); rec = m[3] !== nothing
        mi = _mi_of(M, m[2])
        if mi === nothing
            push!(rows, (ms, rec, "unresolved", "", "", m[2])); continue
        end
        cis = _cis(mi)
        plainold = [ci for ci in cis if ci.owner === nothing && ci in _OLD[]]
        kind = if any(ci -> haskey(rej, ci), cis)
            "rejected at load: " * _causestr(rej[first(ci for ci in cis if haskey(rej, ci))])
        elseif haskey(invset, mi)
            c = invset[mi]; "invalidated: " * string(parentmodule(c), ".", c.name)
        elseif any(ci -> ci.max_world < typemax(UInt) && ci.invoke != C_NULL && ci.owner === nothing, plainold)
            "plain code invalid before the session (no log entry)"
        elseif rec
            "not invalidated: " * join(unique(_own(ci.owner) * (ci.invoke != C_NULL ? "+code" : "") for ci in cis), ",")
        else
            "first compile"
        end
        owners = join(unique(_own(ci.owner) for ci in cis if !(ci in _OLD[]) && ci.max_world == typemax(UInt)), ",")
        hasfacts = any(ci -> ci.owner === :facts, cis) ? "facts copy" : ""
        push!(rows, (ms, rec, kind, owners, hasfacts, m[2]))
    end
    open(out, "w") do io
        sums = Dict{String,Tuple{Int,Float64}}()
        for (ms, rec, kind, owners, hasfacts, s) in rows
            k = rec ? replace(kind, r":.*" => "") : "not marked # recompile"
            n, t = get(sums, k, (0, 0.0)); sums[k] = (n + 1, t + ms)
            println(io, "ROOT ", lpad(round(ms; digits = 1), 7), " ms | ", rec ? "recompile" : "first", " | ", kind,
                    " | new code: ", owners, " | ", hasfacts, " | ", first(s, 220))
        end
        println(io, "# the roots after the load mark by kind (count, ms)")
        for (k, (n, t)) in sort!(collect(sums); by = x -> -x[2][2])
            println(io, "KIND ", rpad(k, 60), lpad(n, 5), lpad(round(Int, t), 7))
        end
        nrej = length(rej)
        bym = Dict{String,Int}()
        for (ci, c) in rej
            k = string(_modroot(_mi(ci)), " <- ", _causestr(c)); bym[k] = get(bym, k, 0) + 1
        end
        println(io, "# image code rejected at load: ", nrej, " CodeInstances, by the package of their method <- the methods that broke an edge")
        for (k, v) in sort!(collect(bym); by = last, rev = true)[1:min(end, 30)]
            println(io, "REJ ", lpad(v, 6), "  ", first(k, 250))
        end
    end
end
