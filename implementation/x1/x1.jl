# E-265 (X1 of the work plan §8; the user, 2026-11-06: "Adopt, keys as optional is approved. Run the X now"):
# what does G2's narrower scope cost in compile time per session of loads?
#
# For each step of a session (a package load, or a work file), E-261's analysis (`../s0a/s0a.jl`, copied here
# unchanged but for what run_step returns) gives set (B): the facts-owner callers of plain code the step
# invalidated, and which of them the code slot would keep. Then, timed:
#   (P) the plain callees in (B)'s edges, compiled again (they are invalid after the load): what the unified
#       build's facts code would wait for; a lower bound, since the analysis re-inferred some of their callees;
#   lost: with the slot, the callers it would not keep, with their facts callers; without it, all of (B) with
#       theirs. Invalidated for real (`jl_invalidate_code_instance`, which takes their callers of any owner too)
#       and compiled again for their owner (`Compiler.typeinf_ext_toplevel`, then `jl_compile_codeinst`).
#   Each case in its own process (X1_MODE below).
# The upper modes give an upper bound; the session modes (X1_MODE below) give what a session's work pays.
#
#     julia --startup-file=no x1.jl <label> <step> [<step> ...]
#       a step: a package name (`using Name` in Main), or `work:<file.jl>` (included in Main).
# Writes <label>.tsv (one row per step), <label>-methods.tsv (the recompiled code, per step) and <label>.txt
# to $X1_OUT (default ./out).
const CC = Base.Compiler
label = ARGS[1]
steps = ARGS[2:end]
outdir = get(ENV, "X1_OUT", joinpath(@__DIR__, "out"))
mkpath(outdir)

# ---- E-261's analysis (../s0a/s0a.jl), unchanged ------------------------------------------------------------
mi_of(x) = x isa Core.CodeInstance ? (x.def isa Core.MethodInstance ? x.def : x.def.def) :
           x isa Core.MethodInstance ? x : nothing

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
            i += 1
        end
    end
    return evs
end

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
            CC.widenconst(t) == krt || return false
            t isa Core.Const && return false
            found = true
        end
    end
    return found
end

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

# the facts code that would be lost with these callers: their valid facts callers, transitively (a set here)
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
    return seen
end

# E-261's run_step, returning the sets (B), its part kept by the slot, and the plain callees
function analyse_step(step::String)
    w0 = Base.get_world_counter()
    log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
    t = @elapsed if startswith(step, "work:")
        Base.include(Main, step[6:end])
    else
        Core.eval(Main, Expr(:using, Expr(:., Symbol(step))))
    end
    ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
    evs = parse_log(log)
    depth = IdDict{Core.MethodInstance,Int}()
    for (tag, ps) in evs
        tag in ("jl_method_table_insert", "jl_method_table_disable") || continue
        for (mi, d) in ps
            depth[mi] = min(get(depth, mi, typemax(Int)), d)
        end
    end
    inv = collect(keys(depth))
    sort!(inv; by = mi -> depth[mi])
    status = IdDict{Core.MethodInstance,Symbol}()
    for mi in inv
        if depth[mi] == 0
            old = isdefined(mi, :cache) ? mi.cache : nothing
            status[mi] = old !== nothing && result_equal(mi, old) ? :equal : :changed
            continue
        end
        cis = invalidated_cis(mi, w0)
        isempty(cis) && (status[mi] = :changed; continue)
        allkept = true
        for c in cis
            callees = Core.MethodInstance[]
            for e in c.edges
                k = mi_of(e)
                k !== nothing && haskey(depth, k) && k !== mi && push!(callees, k)
            end
            kept = !isempty(callees)
            for k in callees
                st = get(status, k, :changed)
                kc = e_ci(c, k)
                krt = kc === nothing ? Any : kc.rettype
                re = kc !== nothing && result_edge(c, k, krt, c.max_world)
                (st === :kept || (re && st === :equal)) || (kept = false)
            end
            allkept &= kept
        end
        status[mi] = allkept ? :kept : (result_equal(mi, first(cis)) ? :equal : :changed)
    end
    B = Base.IdSet{Any}(); keptB = Base.IdSet{Any}(); P = Core.MethodInstance[]
    for mi in inv
        any(c -> c.owner === nothing, invalidated_cis(mi, w0)) || continue
        isdefined(mi, :backedges) || continue
        hasB = false
        for b in mi.backedges
            b isa Core.CodeInstance || continue
            (b.owner === :facts && b.max_world == typemax(UInt)) || continue
            hasB = true
            b in B && continue
            push!(B, b)
            cis = invalidated_cis(mi, w0)
            old = cis[findfirst(c -> c.owner === nothing, cis)]
            if result_edge(b, mi, old.rettype, Base.get_world_counter()) && get(status, mi, :changed) in (:kept, :equal)
                push!(keptB, b)
            end
        end
        hasB && push!(P, mi)
    end
    # a caller kept for one callee may be lost for another: kept only if kept for every invalidated callee
    for b in collect(keptB)
        for e in b.edges
            k = mi_of(e)
            k === nothing && continue
            haskey(depth, k) || continue
            any(c -> c.owner === nothing, invalidated_cis(k, w0)) || continue
            cis = invalidated_cis(k, w0)
            old = cis[findfirst(c -> c.owner === nothing, cis)]
            if !(result_edge(b, k, old.rettype, Base.get_world_counter()) && get(status, k, :changed) in (:kept, :equal))
                delete!(keptB, b); break
            end
        end
    end
    return (; step, t, B, keptB, P)
end

# ---- X1: the timing ----------------------------------------------------------------------------------------
bump!() = Core.eval(Main, :(__x1_bump() = nothing))   # a new world

"Compile `mi` for `owner` at the current world, to machine code; the seconds taken (inference and codegen)."
function compile_for(mi::Core.MethodInstance, @nospecialize(owner))
    w = Base.get_world_counter()
    t0 = time_ns()
    ok = try
        ci = CC.typeinf_ext_toplevel(mi, w, CC.SOURCE_MODE_ABI, CC.TRIM_NO, owner)
        ci isa Core.CodeInstance && ccall(:jl_compile_codeinst, Cint, (Any,), ci)
        true
    catch
        false
    end
    return ((time_ns() - t0) / 1e9, ok)
end

"Invalidate `cis` for real; the CodeInstances that ends (theirs and their callers'), as (mi, owner) pairs."
function invalidate!(cis)
    wB = Base.get_world_counter()
    log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
    for c in cis
        c.max_world == typemax(UInt) || continue
        ccall(:jl_invalidate_code_instance, Cvoid, (Any, Csize_t), c, wB)
    end
    ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
    out = Tuple{Core.MethodInstance,Any,Int}[]
    seen = Base.IdSet{Any}()
    i = 1
    while i <= length(log)
        mi = mi_of(log[i])
        d = (i < length(log) && log[i+1] isa Int32) ? Int(log[i+1]) : 0
        i += mi !== nothing && i < length(log) && log[i+1] isa Int32 ? 2 : 1
        mi === nothing && continue
        isdefined(mi, :cache) || continue
        ci = mi.cache
        while true
            if ci.max_world == wB && !(ci in seen)
                push!(seen, ci); push!(out, (mi, ci.owner, d))
            end
            isdefined(ci, :next) || break
            ci = ci.next
        end
    end
    bump!()
    return out
end

"Compile each (mi, owner) again, callees first (by depth); totals per owner, and the rows."
function recompile!(set, part, step, rows)
    sort!(set; by = x -> x[3])
    tot = Dict{Any,Float64}(); n = Dict{Any,Int}(); fails = 0
    c0 = Base.cumulative_compile_time_ns()
    for (mi, owner, d) in set
        (owner === nothing || owner === :facts) || continue   # TraitWorld's check owner: not code a session runs
        s, ok = compile_for(mi, owner)
        ok || (fails += 1)
        tot[owner] = get(tot, owner, 0.0) + s; n[owner] = get(n, owner, 0) + 1
        push!(rows, (step, part, owner === nothing ? "plain" : string(owner), round(s; digits = 5), mi.def isa Method ? string(parentmodule(mi.def)) : "", string(mi.specTypes)))
    end
    c1 = Base.cumulative_compile_time_ns()
    return (; tot, n, fails, counter = (c1[1] - c0[1]) / 1e9, nset = length(set))
end

# ---- the modes ----------------------------------------------------------------------------------------------
# X1_MODE (each its own process, so that the cases do not overlap):
#   upper-slot, upper-noslot: after each step, (P) compiled again, then the lost set invalidated and compiled
#       again, all timed (an upper bound: every lost CodeInstance compiled again once per load);
#   control, slot, noslot: after each step the lost set is invalidated (nothing for control); after the last
#       step the work file X1_WORK runs, timed, with the compile counter: slot − control is what the session
#       pays with the slot, noslot − control without it. Then the plain callees (P) that the facts code
#       compiled again in the work rests on, compiled plainly (the unified build's facts code calls them).
const MODE = get(ENV, "X1_MODE", "upper-slot")
const WORK = get(ENV, "X1_WORK", "")
const SLOT = MODE in ("upper-slot", "slot")
lostset(a) = SLOT ? collect(facts_closure([b for b in a.B if !(b in a.keptB)])) : collect(facts_closure(collect(a.B)))

Base.cumulative_compile_timing(true)
results = Any[]; mrows = Any[]
lost_all = Tuple{Core.MethodInstance,Any,Int}[]; P_all = Base.IdSet{Core.MethodInstance}()
for s in steps
    a = analyse_step(s)
    bump!()
    foreach(mi -> push!(P_all, mi), a.P)
    if startswith(MODE, "upper")
        rP = recompile!([(mi, nothing, 0) for mi in a.P], "P", s, mrows)
        L = lostset(a)
        inv = invalidate!(L)
        rL = recompile!(inv, "L", s, mrows)
        push!(results, (; step = s, load = a.t, nB = length(a.B), nkept = length(a.keptB), nP = length(a.P), nL = length(L), rP, rL))
        sec(x) = round(sum(values(x.tot); init = 0.0); digits = 3)
        println("$(label) $(rpad(s, 26)) load $(round(a.t; digits = 2)) s; (B) $(length(a.B)), kept by the slot $(length(a.keptB)); " *
                "(P) $(rP.nset) plain callees $(sec(rP)) s; lost $(length(L)) → $(rL.nset) invalidated, compiled again $(sec(rL)) s " *
                "[$(join(["$(k === nothing ? "plain" : k) $(v) in $(round(rL.tot[k]; digits=3)) s" for (k, v) in rL.n], ", "))]; fails $(rP.fails + rL.fails)")
    else
        L = MODE == "control" ? Any[] : lostset(a)
        inv = isempty(L) ? Tuple{Core.MethodInstance,Any,Int}[] : invalidate!(L)
        append!(lost_all, inv)
        push!(results, (; step = s, load = a.t, nB = length(a.B), nkept = length(a.keptB), nP = length(a.P), nL = length(L), ninv = length(inv)))
        println("$(label) $(rpad(s, 26)) load $(round(a.t; digits = 2)) s; (B) $(length(a.B)), kept by the slot $(length(a.keptB)); lost $(length(L)) → $(length(inv)) invalidated")
    end
    flush(stdout)
end
sec(x) = sum(values(x.tot); init = 0.0)
if startswith(MODE, "upper")
    open(joinpath(outdir, "$(label).tsv"), "w") do io
        println(io, "step\tload_s\tB\tB_kept\tP_n\tP_s\tlost_seed\tlost_inv\tlost_facts_n\tlost_plain_n\tlost_s\tfails")
        for r in results
            println(io, join((r.step, round(r.load; digits = 3), r.nB, r.nkept, r.rP.nset, round(sec(r.rP); digits = 4),
                r.nL, r.rL.nset, get(r.rL.n, :facts, 0), get(r.rL.n, nothing, 0), round(sec(r.rL); digits = 4), r.rP.fails + r.rL.fails), '\t'))
        end
    end
    tP = sum(r -> sec(r.rP), results; init = 0.0); tL = sum(r -> sec(r.rL), results; init = 0.0)
    summary = """
    E-265 $(label) ($(MODE)): $(length(results)) steps on $(Base.GIT_VERSION_INFO.commit_short), machine load $(read("/proc/loadavg", String)[1:4])
      (B) facts callers of invalidated plain code $(sum(r -> r.nB, results)); kept by the slot $(sum(r -> r.nkept, results))
      (P) plain callees compiled again: $(sum(r -> r.rP.nset, results)) in $(round(tP; digits = 3)) s
      lost $(SLOT ? "with" : "without") the slot: $(sum(r -> r.rL.nset, results)) CodeInstances invalidated and compiled again in $(round(tL; digits = 3)) s
    """
else
    # the work, timed
    GC.gc()
    c0 = Base.cumulative_compile_time_ns()
    tw = @elapsed Base.include(Main, WORK)
    c1 = Base.cumulative_compile_time_ns()
    # the lost code the work compiled again, and the plain callees (P) it rests on that have no plain code now
    again = 0; Pneed = Core.MethodInstance[]
    seenP = Base.IdSet{Core.MethodInstance}()
    for (mi, owner, d) in lost_all
        owner === :facts || continue
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        newci = nothing
        while ci !== nothing
            ci.owner === :facts && ci.max_world == typemax(UInt) && (newci = ci; break)
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
        newci === nothing && continue
        global again += 1
        for e in newci.edges
            k = mi_of(e)
            (k !== nothing && k in P_all && !(k in seenP)) || continue
            push!(seenP, k)
            any_plain = false
            c = isdefined(k, :cache) ? k.cache : nothing
            while c !== nothing
                c.owner === nothing && c.max_world == typemax(UInt) && (any_plain = true; break)
                c = isdefined(c, :next) ? c.next : nothing
            end
            any_plain || push!(Pneed, k)
        end
    end
    rP = recompile!([(mi, nothing, 0) for mi in Pneed], "P-after-work", "work", mrows)
    open(joinpath(outdir, "$(label).tsv"), "w") do io
        println(io, "mode\twork_s\twork_compile_s\twork_recompile_s\tlost_inv\tlost_compiled_in_work\tP_needed\tP_s")
        println(io, join((MODE, round(tw; digits = 4), round((c1[1] - c0[1]) / 1e9; digits = 4), round((c1[2] - c0[2]) / 1e9; digits = 4),
            length(lost_all), again, length(Pneed), round(sec(rP); digits = 4)), '\t'))
    end
    summary = """
    E-265 $(label) ($(MODE)): $(length(results)) steps on $(Base.GIT_VERSION_INFO.commit_short), machine load $(read("/proc/loadavg", String)[1:4])
      (B) facts callers of invalidated plain code $(sum(r -> r.nB, results)); kept by the slot $(sum(r -> r.nkept, results)); lost and invalidated $(length(lost_all))
      the work: $(round(tw; digits = 3)) s, compile counter $(round((c1[1] - c0[1]) / 1e9; digits = 3)) s (of it recompiling $(round((c1[2] - c0[2]) / 1e9; digits = 3)) s)
      lost code compiled again in the work: $(again) facts CodeInstances; their plain callees without code: $(length(Pneed)), compiled in $(round(sec(rP); digits = 3)) s
    """
end
open(joinpath(outdir, "$(label)-methods.tsv"), "w") do io
    println(io, "step\tpart\towner\tseconds\tmodule\tspecTypes")
    for m in mrows; println(io, join(m, '\t')); end
end
print(summary)
write(joinpath(outdir, "$(label).txt"), summary)
