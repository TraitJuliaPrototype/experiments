# E-537: the samples of the sampling profiler (C frames included), classed. Included by run.jl and nd_steady.jl.
#
# Each sample is classed twice:
# - its context, from the whole stack: the right-hand side at duals inside the Jacobian; the right-hand side
#   (at Float64: the stages, the time derivative's differences, the first step); the Jacobian's own work (the duals'
#   seeding and reading; upstream's time derivative by duals); the factorization (getrf, `lu!`); the solves (getrs,
#   trsv, `ldiv!`); callbacks; the step's arithmetic (rodas5_step!/perform_step!); the rest (the driver, saving, ...);
# - its run-time part, from the C frames at its leaf, below the innermost Julia frame: GC; allocation; dispatch at
#   run time (jl_apply_generic, jl_invoke, the lookup, a typeassert's or isa's subtyping); or none (Julia code,
#   BLAS, libm); or the box: the innermost Julia frame is the box's call (TraitWorld's callable.jl). A sample under
#   the box's call or core_rhs! counts as the right-hand side's.
# Then the innermost Julia frames and C frames by count, so a class can be read back to the code.
using Profile

const RHS_NAMES = Set(["bruss!", "pollu!"])
const JAC_PAT = r"^(dual_jacobian!|_ad_jacobian!|pjacobian!|jacobian!|calc_J!|calc_tderivative!|jacobian|forwarddiff_color_jacobian|derivative!|_value_and_derivative|value_and_jacobian!|_jacobian!|jacobian_loop!|vector_mode_jacobian!|chunk_mode_jacobian!|jacobian_chunk_mode_expr|seed!|extract_jacobian_chunk!|dual_jacobian)$"
const FACT_PAT = r"(getrf|^lu!$|^lu$|generic_lufact!|LUFactorization|^do_factorization$|init_cacheval|^linfactor$|dgetf2|dlaswp)"
const SOLVE_PAT = r"(getrs|trsv|trsm|^ldiv!$|^ldiv$|_ldiv_basic)"
const CB_PAT = r"^(bruss_cond|bruss_affect!|pollu_cond|pollu_affect!|step_condition|step_affect!|condition|affect!|apply_discrete_callback!|handle_callbacks!|discrete_callback!|discrete_callbacks!|_discrete_callback|reset_pulse!)$"
const STEP_PAT = r"^(rodas5_step!|perform_step!|rosenbrock_step!)$"
const GC_PAT = r"(^gc_|_gc_collect|jl_gc_collect|gc_mark|gc_sweep|jl_gc_wait|gc_heap|sweep_|jl_safepoint|gc_queue|gc_scan|mark_|jl_gc_free|gc_try_claim|jl_gc_mark)"
const ALLOC_PAT = r"(jl_gc_alloc|gc_small_alloc|gc_pool_alloc|gc_big_alloc|jl_alloc_|_new_genericmemory|genericmemory|jl_gc_managed_malloc|^malloc$|jl_gc_counted_malloc|_int_malloc|jl_new_struct|jl_box_|ijl_box_|jl_gc_small_alloc|ijl_gc_small_alloc|jl_array_|memmove|memset|__memset|__memmove|^calloc$)"
const DISP_PAT = r"(apply_generic|jl_invoke|ijl_invoke|jl_lookup_generic|gf_invoke|jl_method_lookup|jl_gf_|typeassert|jl_type_error|jl_isa|ijl_isa|jl_subtype|ijl_subtype|jl_types_equal|jl_f__apply|jl_f_isa|jl_f_typeassert|jl_typemap|jl_obvious_subtype|jl_egal|forall_exists|subtype_|jl_type_intersection|lookup_|jl_get_|cache_method|jl_typeof_|_jl_invoke|jl_f_invoke|jl_call_|invoke_codeinst|jl_new_structv|jl_lookup_|jl_specializations|first_methcache|jl_tl|jl_dispatch|jl_trait|int64hash|inst_datatype|jl_apply_type|typekey|obvious_subtype|jl_instantiate|lookup_type|jl_tupletype|arg_type_tuple|jl_f_tuple|jl_new_datatype)"

# what marks a frame as the right-hand side's, a callback's: the stiff problems' by default; nd_steady.jl sets its own
const RHS_FRAME = Ref{Function}(fr -> String(fr.func) in RHS_NAMES)
const CB_FRAME = Ref{Function}(fr -> occursin(CB_PAT, String(fr.func)))
# whether a sample under a callback is the callback's even where it calls the right-hand side (NetworkDynamics'
# conditions evaluate the network's outputs): set by nd_steady.jl
const CB_FIRST = Ref(false)
const _lk = Dict{UInt64,Vector{Base.StackTraces.StackFrame}}()
frames(ip) = get!(() -> Profile.lookup(ip), _lk, UInt64(ip))
fname(fr) = String(fr.func)

function context(stack)
    has_rhs = has_jac = has_fact = has_solve = has_cb = has_step = false
    for fr in stack
        n = fname(fr)
        if fr.from_c
            occursin(FACT_PAT, n) && (has_fact = true)
            occursin(r"(getrs|trsv|trsm)", n) && (has_solve = true)
            continue
        end
        (RHS_FRAME[](fr) || n == "core_rhs!" || isbox(fr)) && (has_rhs = true)
        occursin(JAC_PAT, n) && (has_jac = true)
        occursin(FACT_PAT, n) && (has_fact = true)
        occursin(SOLVE_PAT, n) && (has_solve = true)
        CB_FRAME[](fr) && (has_cb = true)
        occursin(STEP_PAT, n) && (has_step = true)
    end
    CB_FIRST[] && has_cb && return "callbacks"
    has_rhs && has_jac && return "rhs at duals (Jacobian)"
    has_jac && return "Jacobian, the rest"
    has_rhs && return "rhs (Float64)"
    has_fact && return "factorization"
    has_solve && return "solves (ldiv)"
    has_cb && return "callbacks"
    has_step && return "step arithmetic"
    return "the rest (driver, saving, ...)"
end

# the run-time part: the C frames below the innermost Julia frame
function runtime_part(stack)
    gc = alloc = disp = false
    for fr in stack
        fr.from_c || break
        n = fname(fr)
        occursin(GC_PAT, n) && (gc = true)
        occursin(ALLOC_PAT, n) && (alloc = true)
        occursin(DISP_PAT, n) && (disp = true)
    end
    gc && return "gc"
    alloc && return "alloc"
    disp && return "dispatch"
    i = findfirst(fr -> !fr.from_c, stack)
    i !== nothing && isbox(stack[i]) && return "box"
    return "code"
end
# the box's call: TraitWorld's `Dynamic{Callable…}` call methods (callable.jl), the argument and result checks
isbox(fr) = !fr.from_c && basename(String(fr.file)) == "callable.jl" && occursin("TraitWorld", String(fr.file)) ||
            String(fr.func) in ("_call_at_signatures", "_checked_result")
# under the box: one of the three innermost Julia frames is the box's call (its dispatch, its checks)
under_box(stack) = (k = 0; for fr in stack; fr.from_c && continue; isbox(fr) && return true; (k += 1) >= 3 && break; end; false)
innermost_julia(stack) = (i = findfirst(fr -> !fr.from_c, stack);
    i === nothing ? "(no Julia frame)" : (fr = stack[i]; "$(fname(fr)) $(basename(String(fr.file))):$(fr.line)"))
innermost_c(stack) = (fr = stack[1]; fr.from_c ? fname(fr) : "(Julia)")

function profclass(io::IO, label::AbstractString, nsolves::Integer; top = 30, root = "one_solve")
    data = Profile.fetch(include_meta = false)
    samples = Vector{Vector{Base.StackTraces.StackFrame}}()
    cur = Base.StackTraces.StackFrame[]
    for ip in data
        if ip == 0
            isempty(cur) || push!(samples, cur)
            cur = Base.StackTraces.StackFrame[]
        else
            append!(cur, frames(ip))
        end
    end
    isempty(cur) || push!(samples, cur)
    # only the samples inside a solve: the stack holds `root`
    samples = filter(s -> any(fr -> fname(fr) == root, s), samples)
    N = length(samples)
    ctx = Dict{Tuple{String,String},Int}()
    jl = Dict{String,Int}(); cf = Dict{String,Int}(); dj = Dict{String,Int}()
    for s in samples
        k = (context(s), runtime_part(s))
        ctx[k] = get(ctx, k, 0) + 1
        j = innermost_julia(s); jl[j] = get(jl, j, 0) + 1
        c = innermost_c(s); cf[c] = get(cf, c, 0) + 1
        k[2] == "dispatch" && (dj[j] = get(dj, j, 0) + 1)
    end
    println(io, label, " | samples in solves ", N, " | solves ", nsolves, " | samples per solve ", round(N / nsolves; digits = 2))
    ctxs = sort(unique(first.(collect(keys(ctx)))); by = c -> -sum(v for (k, v) in ctx if k[1] == c))
    parts = ["code", "box", "dispatch", "alloc", "gc"]
    println(io, label, " | context | all % | code % | box % | dispatch % | alloc % | gc %")
    for c in ctxs
        tot = sum(get(ctx, (c, p), 0) for p in parts)
        println(io, label, " | ", c, " | ", round(100tot / N; digits = 1), " | ",
                join([round(100get(ctx, (c, p), 0) / N; digits = 1) for p in parts], " | "))
    end
    println(io, label, " | all | 100 | ", join([round(100sum(get(ctx, (c, p), 0) for c in ctxs) / N; digits = 1) for p in parts], " | "))
    nb = count(under_box, samples)
    println(io, label, " | under the box's call (one of the three innermost Julia frames; its dispatch included): ", round(100nb / N; digits = 1), " %")
    println(io, label, " | the innermost Julia frames, the first $top:")
    for (k, v) in first(sort(collect(jl); by = kv -> -kv[2]), top)
        println(io, label, " |   ", lpad(round(100v / N; digits = 1), 5), " %  ", k)
    end
    println(io, label, " | the dispatch samples by their innermost Julia frame (the call left to run time), the first 12:")
    for (k, v) in first(sort(collect(dj); by = kv -> -kv[2]), 12)
        println(io, label, " |   ", lpad(round(100v / N; digits = 1), 5), " %  ", k)
    end
    println(io, label, " | the innermost C frames (a sample whose leaf is Julia code: \"(Julia)\"), the first 20:")
    for (k, v) in first(sort(collect(cf); by = kv -> -kv[2]), 20)
        println(io, label, " |   ", lpad(round(100v / N; digits = 1), 5), " %  ", k)
    end
end
