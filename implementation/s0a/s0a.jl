# E-261 (W-S0a, the user 2026-11-06: "Agreed on W-S0a."): how much invalidated code would the code slot keep
# (compiler §7.7)? For each step of a session (a package load, or a work file):
#
# (A) all code. Julia's invalidation log over the step; each method insertion's invalidated MethodInstances as
#     trees (callers with their depth, the root last). For each invalidated CodeInstance its edges to other
#     invalidated MethodInstances are classified:
#       - a result edge: the caller's optimized code (re-inferred at the caller's last valid world) has an
#         `:invoke` of the callee whose statement type is the callee's old result type, no narrower (review M7);
#       - a code edge: anything else (inlined, constant-propagated, concrete-evaluated, no `:invoke`).
#     Each invalidated MethodInstance that is not kept is re-inferred in the new world and its result (type,
#     exception type, effects, constant) compared with the old CodeInstance's. Red-green from the roots: a caller
#     is kept when every edge to an invalidated callee is a result edge to a callee that is kept or whose result
#     is equal.
# (B) the unified build's edges from facts code to plain code. In the product setting today a facts caller calls
#     the facts copy of a neutral method, which loads do not invalidate. In the unified build it calls the plain
#     CodeInstance. So: for each invalidated plain CodeInstance, the facts-owner callers in its MethodInstance's
#     backedges that are still valid are lost without the slot; with it, each is kept under the rule of (A).
#
#     julia --startup-file=no --project=<env> s0a.jl <label> <step> [<step> ...]
#       a step: a package name (`using Name` in Main), or `work:<file.jl>` (included in Main).
# Writes <label>.tsv (one row per step) and <label>.txt (a summary) to $S0A_OUT (default: ./out).
const CC = Base.Compiler
label = ARGS[1]
steps = ARGS[2:end]
outdir = get(ENV, "S0A_OUT", joinpath(@__DIR__, "out"))
mkpath(outdir)

mi_of(x) = x isa Core.CodeInstance ? (x.def isa Core.MethodInstance ? x.def : x.def.def) :
           x isa Core.MethodInstance ? x : nothing

# the log as (tag, [(mi, depth)...]) per root; depth 0 is the root
function parse_log(log)
    evs = Tuple{String,Vector{Tuple{Core.MethodInstance,Int}}}[]
    pend = Tuple{Core.MethodInstance,Int}[]
    i = 1
    while i <= length(log)
        x = log[i]
        mi = mi_of(x)
        if mi !== nothing
            if i < length(log) && log[i+1] isa Int32
                push!(pend, (mi, Int(log[i+1]))); i += 2
            else
                push!(pend, (mi, 0)); i += 1
            end
        elseif x isa String
            isempty(pend) || push!(evs, (x, copy(pend)))
            empty!(pend)
            i += 1
        else
            i += 1   # the cause (a Method, a signature) after a tag
        end
    end
    return evs
end

# the CodeInstances of mi invalidated in this step
function invalidated_cis(mi::Core.MethodInstance, w0::UInt)
    out = Core.CodeInstance[]
    isdefined(mi, :cache) || return out
    ci = mi.cache
    while true
        if ci.max_world != typemax(UInt) && ci.max_world >= w0
            push!(out, ci)
        end
        isdefined(ci, :next) || break
        ci = ci.next
    end
    return out
end

# is the edge from caller code `c` to callee `kmi` a result edge? (an :invoke of kmi whose type is k's result)
const IR_CACHE = IdDict{Any,Any}()
function caller_ir(c::Core.CodeInstance, world::UInt)
    get!(IR_CACHE, c) do
        mi = mi_of(c)
        try
            r = Base.code_typed_by_type(mi.specTypes; world = world, optimize = true)
            length(r) == 1 ? first(first(r)) : nothing
        catch
            nothing
        end
    end
end
function result_edge(c::Core.CodeInstance, kmi::Core.MethodInstance, krt, world::UInt)
    ir = caller_ir(c, world)
    ir === nothing && return false
    found = false
    for (i, s) in enumerate(ir.code)
        if s isa Expr && s.head === :invoke
            tgt = s.args[1]
            mi_of(tgt) === kmi || continue
            t = ir.ssavaluetypes[i]
            CC.widenconst(t) == krt || return false      # narrower: constant propagation used the callee's code
            t isa Core.Const && return false
            found = true
        end
    end
    return found
end

# the callee's result now, against the old CodeInstance's: the call at the callee's signature dispatched and
# inferred in the new world (for a root, whose dispatch changed, that is the method now selected)
function result_equal(kmi::Core.MethodInstance, old::Core.CodeInstance)
    try
        ms = Base._methods_by_ftype(kmi.specTypes, -1, Base.get_world_counter())
        (ms isa Vector && length(ms) == 1) || return false
        mi2 = CC.specialize_method(ms[1])
        frame = CC.typeinf_frame(CC.NativeInterpreter(), mi2, false)
        frame === nothing && return false
        res = frame.result
        rt = res.result
        CC.widenconst(rt) == old.rettype || return false
        oldconst = isdefined(old, :rettype_const) && (old.flags & 0x2) != 0   # the old result was a constant
        if rt isa Core.Const
            isdefined(old, :rettype_const) && isequal(old.rettype_const, rt.val) || return false
        end
        CC.widenconst(res.exc_result) == old.exctype || return false
        CC.encode_effects(res.ipo_effects) == old.ipo_purity_bits || return false
        return true
    catch err
        return false
    end
end

function run_step(step::String)
    w0 = Base.get_world_counter()   # an invalidated CodeInstance keeps max_world = the world before the insertion
    log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
    t = @elapsed if startswith(step, "work:")
        Base.include(Main, step[6:end])
    else
        Core.eval(Main, Expr(:using, Expr(:., Symbol(step))))   # as a session writes it: `using X`
    end
    ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
    evs = parse_log(log)
    tags = Dict{String,Int}()
    for (tag, ps) in evs; tags[tag] = get(tags, tag, 0) + length(ps); end
    # (A) the invalidation trees of method insertions
    depth = IdDict{Core.MethodInstance,Int}()
    for (tag, ps) in evs
        tag in ("jl_method_table_insert", "jl_method_table_disable") || continue
        for (mi, d) in ps
            depth[mi] = min(get(depth, mi, typemax(Int)), d)
        end
    end
    inv = collect(keys(depth))
    sort!(inv; by = mi -> depth[mi])
    status = IdDict{Core.MethodInstance,Symbol}()   # :kept, :equal, :changed
    nci = Dict{Any,Int}(); kept_ci = Dict{Any,Int}(); resonly_ci = Dict{Any,Int}()
    for mi in inv
        if depth[mi] == 0
            # a root: its dispatch changed; its own CodeInstances stay valid for the old method. Its status is the
            # result of the call at its signature in the new world against its old result.
            old = isdefined(mi, :cache) ? mi.cache : nothing
            status[mi] = old !== nothing && result_equal(mi, old) ? :equal : :changed
            continue
        end
        cis = invalidated_cis(mi, w0)
        isempty(cis) && (status[mi] = :changed; continue)
        allkept = true
        for c in cis
            own = c.owner
            nci[own] = get(nci, own, 0) + 1
            callees = Core.MethodInstance[]
            for e in c.edges
                k = mi_of(e)
                k !== nothing && haskey(depth, k) && k !== mi && push!(callees, k)
            end
            # kept: every invalidated callee is kept (its code is unchanged, so any edge to it holds), or is
            # re-inferred to an equal result and reached by a result edge (the slot re-resolves the call)
            kept = !isempty(callees)
            resonly = kept
            for k in callees
                st = get(status, k, :changed)
                kc = e_ci(c, k)
                krt = kc === nothing ? Any : kc.rettype
                re = kc !== nothing && result_edge(c, k, krt, c.max_world)
                re || (resonly = false)
                (st === :kept || (re && st === :equal)) || (kept = false)
            end
            resonly && (resonly_ci[own] = get(resonly_ci, own, 0) + 1)
            kept && (kept_ci[own] = get(kept_ci, own, 0) + 1)
            allkept &= kept
        end
        if allkept
            status[mi] = :kept
        else
            old = first(cis)
            status[mi] = result_equal(mi, old) ? :equal : :changed
        end
    end
    # (B) facts callers of invalidated plain code
    nB = 0; keptB = 0; closureB = 0
    for mi in inv
        any(c -> c.owner === nothing, invalidated_cis(mi, w0)) || continue
        isdefined(mi, :backedges) || continue
        seen = Base.IdSet{Any}()
        for b in mi.backedges
            b isa Core.CodeInstance || continue
            (b.owner === :facts && b.max_world == typemax(UInt)) || continue
            b in seen && continue
            push!(seen, b)
            nB += 1
            plain = findfirst(c -> c.owner === nothing, invalidated_cis(mi, w0))
            old = invalidated_cis(mi, w0)[plain]
            if result_edge(b, mi, old.rettype, Base.get_world_counter()) && get(status, mi, :changed) in (:kept, :equal)
                keptB += 1
            end
        end
        closureB += facts_closure(seen)
    end
    return (; step, t, nlog = length(log), tags, ninv = length(inv),
              roots = count(mi -> depth[mi] == 0, inv), nci, kept_ci, resonly_ci,
              equal = count(mi -> get(status, mi, :changed) === :equal, inv),
              kept_mi = count(mi -> get(status, mi, :changed) === :kept, inv), nB, keptB, closureB)
end

# the CodeInstance that caller c's edge names for callee k (the edge itself when it is one; else k's of c's owner)
function e_ci(c::Core.CodeInstance, k::Core.MethodInstance)
    for e in c.edges
        e isa Core.CodeInstance && mi_of(e) === k && return e
    end
    isdefined(k, :cache) || return nothing
    ci = k.cache
    while true
        ci.owner === c.owner && return ci
        isdefined(ci, :next) || return nothing
        ci = ci.next
    end
end

# the facts code that would be lost with these callers: their valid facts callers, transitively
function facts_closure(start)
    seen = Base.IdSet{Any}(start)
    work = collect(start)
    while !isempty(work)
        c = pop!(work)
        mi = mi_of(c)
        isdefined(mi, :backedges) || continue
        for b in mi.backedges
            b isa Core.CodeInstance || continue
            (b.owner === :facts && b.max_world == typemax(UInt)) || continue
            b in seen && continue
            push!(seen, b); push!(work, b)
        end
    end
    return length(seen)
end

fmt(d) = join(["$(k === nothing ? "plain" : k)=$(v)" for (k, v) in sort!(collect(d); by = x -> string(x[1]))], ",")
rows = Any[]
for s in steps
    r = run_step(s)
    push!(rows, r)
    println("$(label) $(rpad(r.step, 28)) load $(round(r.t; digits = 2)) s; log $(r.nlog); invalidated MIs $(r.ninv) (roots $(r.roots)); CIs [$(fmt(r.nci))]; result-edge-only [$(fmt(r.resonly_ci))]; kept [$(fmt(r.kept_ci))]; MIs kept $(r.kept_mi), re-inferred equal $(r.equal); (B) facts callers $(r.nB), kept $(r.keptB), closure $(r.closureB); tags $(r.tags)")
end
open(joinpath(outdir, "$(label).tsv"), "w") do io
    println(io, "step\tload_s\tlog\tinv_mi\troots\tcis\tresult_only\tkept_cis\tkept_mi\tequal_mi\tB_callers\tB_kept\tB_closure")
    for r in rows
        println(io, join((r.step, round(r.t; digits = 3), r.nlog, r.ninv, r.roots, fmt(r.nci), fmt(r.resonly_ci), fmt(r.kept_ci), r.kept_mi, r.equal, r.nB, r.keptB, r.closureB), '\t'))
    end
end
tot(f) = sum(f, rows; init = 0)
totd(f) = sum(r -> sum(values(f(r)); init = 0), rows; init = 0)
summary = """
E-261 $(label): $(length(rows)) steps on $(Base.GIT_VERSION_INFO.commit_short)
  (A) invalidated MethodInstances $(tot(r -> r.ninv)) (roots $(tot(r -> r.roots))); invalidated CodeInstances $(totd(r -> r.nci))
      callers with result edges only $(totd(r -> r.resonly_ci)); kept by the slot $(totd(r -> r.kept_ci)) of $(totd(r -> r.nci)) CodeInstances
  (B) facts-owner callers of invalidated plain code $(tot(r -> r.nB)) (with their facts callers $(tot(r -> r.closureB))); kept by the slot $(tot(r -> r.keptB))
"""
print(summary)
write(joinpath(outdir, "$(label).txt"), summary)
