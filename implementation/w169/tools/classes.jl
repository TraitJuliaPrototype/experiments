# W-169 (E-536): the profile's classes and the report of one phase (tools/prof.jl includes it in its prof mode).
# The profiler is driven through the runtime's own entry points (as the Profile standard library does), and its
# frames are looked up with Base's `StackTraces.lookup`: the standard library is not loaded. Loading it before a
# session changed which cache files the session's loads accepted (the first profiled runs on the head precompiled
# packages inside the timed loads: logs/r1/frames-*-H-prof-1.out, the stale pidfiles' warnings).
# ---- the classes. Each: a name, the frame names that select it (a substring of a function's name). The first
# class in this order with a matching frame anywhere on the stack takes the sample.
const CLASSES = [
    ("garbage collection",                 ["jl_gc_collect", "gc_mark_loop", "gc_sweep", "_jl_gc_collect", "gc_collect_neighbors"]),
    ("load: the membership walk",          ["jl_membership_dispatch_walk", "jl_membership_removal_walk"]),
    ("load: the memberships' activation",  ["jl_memberships_activated", "jl_activate_memberships", "jl_membership_update_cells", "jl_membership_ambiguity_report", "jl_member_checks_activated"]),
    ("load: methods' insertion and invalidation", ["jl_activate_methods", "jl_method_table_activate", "invalidate_code_instance", "invalidate_backedges", "jl_method_table_disable", "jl_method_table_insert"]),
    ("load: the library's image hook",     ["_image_methods_hook"]),
    ("load: package callbacks",            ["run_package_callbacks"]),
    ("load: __init__",                     ["run_module_init", "jl_module_run_initializer", "jl_init_restored_module"]),
    ("load: the edges' validation",        ["insert_backedges", "verify_method_graph", "verify_call", "jl_verify_", "verify_methods", "_insert_backedges"]),
    ("load: the images' restore",          ["jl_restore_package_image", "jl_restore_incremental", "jl_restore_system_image", "_include_from_serialized"]),
    ("the definition-time check",          ["jl_call_definition_hook", "_definition_hook", "_module_end_hook", "_expand_definition"]),
    ("the member check (the library's hook)", ["_member_hook", "jl_member_queue_drain", "jl_member_note_use"]),
    ("compiling while inferring",          String[]),     # code compiled below an inference frame: see class_of
    ("inference",                          :inference),
    ("code generation",                    ["jl_emit_", "jl_compile_codeinst", "jl_generate_fptr", "JuliaOJIT", "jl_add_to_ee", "jl_compile_method_internal", "jl_compile_workqueue", "llvm::"]),
    ("dispatch: a split's pointer made",   ["jl_split_table_miss", "_split_table_miss!"]),
    ("dispatch: the box's checks",         ["_callable_box_check", "_callable_met", "_forward_box", "_dynamic_field_type"]),
    ("dispatch: lookup, the slow path",    ["jl_lookup_generic", "ml_matches", "jl_mt_assoc_by_type", "jl_gf_invoke_lookup", "jl_matching_methods", "jl_method_lookup"]),
    ("lowering and parsing",               ["jl_expand", "jl_lower", "fl_applyn", "jl_parse", "JuliaLowering", "JuliaSyntax", "jl_fl_"]),
    ("definitions",                        ["jl_method_def", "jl_new_datatype", "jl_declare_const", "jl_declare_global"]),
    ("load: the rest (finding files, reading)", ["_require", "__require", "_tryrequire", "require_stdlib", "_require_search_from_serialized"]),
]
# the runtime's dispatch entry points: a sample whose C frames nearest the leaf (before any Julia frame) include one
# of these is dispatch at run time, the fast path (the caches hit; the lookup's slow path and compiles are above)
const DISPATCH = ["jl_apply_generic", "jl_invoke", "jl_gf_invoke", "jl_typemap_entry_assoc_exact", "jl_typemap_assoc_exact",
                  "jl_method_compiled", "jl_f__call_latest", "jl_f_invoke", "jl_f__apply_iterate", "jl_get_ci_from_mi", "jl_mi_cache_lookup"]
const FLAGS = [("inf", :inference), ("gen", ["jl_emit_", "jl_compile_codeinst", "JuliaOJIT", "jl_generate_fptr", "llvm::"]),
               ("sub", ["jl_subtype", "jl_type_intersection", "intersect"]),
               ("mem", ["jl_subtype_via_membership", "jl_membership_holds_at", "jl_membership_entries_for", "jl_type_has_memberships", "jl_membership_world"]),
               ("gc", ["jl_gc_collect"])]
const NESTED = ["jl_compile_method_internal", "jl_generate_fptr", "jl_emit_", "jl_compile_codeinst"]
const INFC = "jl_type_infer"
const I_CWI = findfirst(c -> c[1] == "compiling while inferring", CLASSES)
const I_INF = I_CWI + 1; const I_GEN = I_CWI + 2
const LOADCLS = 2:11       # a load's part or a hook: with what it does (compiling, inferring, the rest)
# inference's own frames by name (a substring "typeinf" would take `invoke_in_typeinf_world`, which the edges'
# validation at a load and other callers use without inferring)
const INFNAMES = ("typeinf_local", "typeinf_ext", "typeinf_frame", "typeinf_edge", "typeinf_nocycle", "jl_type_infer", "ijl_type_infer",
                  "abstract_call", "abstract_eval", "typeinf_ircode")
isinf(nm) = nm == "typeinf" || any(p -> startswith(nm, p), INFNAMES)
hit(name, keys) = keys === :inference ? isinf(name) : any(k -> occursin(k, name), keys)
# names, from_c: leaf first
function class_of(names, fromc)
    best = length(CLASSES) + 1
    for nm in names
        for k in 1:best-1
            hit(nm, CLASSES[k][2]) && (best = k; break)
        end
    end
    if best in (I_INF, I_GEN)       # inference or code generation: is an outer inference running?
        outer = findlast(nm -> occursin(INFC, nm), names)
        if outer !== nothing && any(i -> hit(names[i], NESTED), 1:outer-1)
            best = I_CWI
        end
    end
    if best > length(CLASSES)
        for i in eachindex(names)          # the C frames nearest the leaf
            fromc[i] || break
            hit(names[i], DISPATCH) && return "dispatch: the runtime's fast path"
        end
        return "the work itself"
    end
    c = CLASSES[best][1]
    if best in LOADCLS
        c *= any(nm -> hit(nm, NESTED) || hit(nm, FLAGS[2][2]), names) ? ": compiling" :
             any(nm -> hit(nm, FLAGS[1][2]), names) ? ": inferring" : ""
    end
    return c
end
leafname(s) = startswith(s, "_Z") ? "LLVM (C++)" : s in ("_int_malloc", "_int_free", "malloc", "free", "cfree", "malloc_consolidate", "unlink_chunk.isra.0") ? "malloc" :
              s in ("syscall", "read", "__open64", "access", "__open64_nocancel", "fstatfs", "__mmap64", "stat64", "__GI___fstatat64", "close", "__close_nocancel", "pread64", "__libc_pread64", "__GI___libc_read") ? "file system calls" : first(s, 48)

const TOT = Dict{String,Int}()                 # over all phases: class -> samples
const LOOKUP = Dict{UInt64,Vector{Tuple{String,Bool}}}()
framesof(ip) = get!(LOOKUP, ip) do
    [(string(f.func), f.from_c) for f in Base.StackTraces.lookup(convert(Ptr{Cvoid}, ip))]
end
function report(name, t, data)
    cache = LOOKUP
    cls = Dict{String,Int}(); flg = Dict{String,Vector{Int}}(); leaves = Dict{String,Dict{String,Int}}()
    jl = Dict{String,Int}()       # for "the work itself" and dispatch: the innermost Julia function
    jr = Dict{String,Int}()       # for the load's rest: the innermost Julia function below `require`
    total = 0; start = 1; n = length(data); i = 3
    while i <= n
        if data[i] == 0 && data[i-1] == 0 && data[i-2] in 1:3
            tid = data[i-5]; sleeping = data[i-2] != 1
            frames = @view data[start:i-6]; start = i + 1
            if tid == 1 && !sleeping && !isempty(frames)
                total += 1
                fr = Tuple{String,Bool}[]
                for ip in frames
                    append!(fr, framesof(ip))
                end
                names = first.(fr); fromc = last.(fr)
                c = class_of(names, fromc)
                cls[c] = get(cls, c, 0) + 1
                f = get!(() -> zeros(Int, length(FLAGS)), flg, c)
                for (k, (_, keys)) in enumerate(FLAGS); any(nm -> hit(nm, keys), names) && (f[k] += 1); end
                lf = isempty(names) ? "?" : leafname(names[1])
                d = get!(() -> Dict{String,Int}(), leaves, c); d[lf] = get(d, lf, 0) + 1
                if c == "the work itself" || startswith(c, "dispatch")
                    k = findfirst(!, fromc)
                    jf = k === nothing ? "?" : first(names[k], 60)
                    jl[jf] = get(jl, jf, 0) + 1
                elseif startswith(c, "load: the rest")
                    k = findfirst(!, fromc)
                    jf = k === nothing ? "?" : first(names[k], 60)
                    jr[jf] = get(jr, jf, 0) + 1
                end
            end
            i += 3
        else
            i += 1
        end
    end
    println("## ", name, ": ", round(1000t; digits = 1), " ms, ", total, " samples")
    for (c, v) in sort(collect(cls); by = last, rev = true)
        TOT[c] = get(TOT, c, 0) + v
        f = flg[c]
        fl = join(["$(FLAGS[k][1]) $(round(Int, 100f[k] / v))" for k in eachindex(FLAGS) if f[k] > 0], ", ")
        top = join(["$(first(l)) $(round(Int, 100last(l) / v))" for l in first(sort(collect(leaves[c]); by = last, rev = true), 4)], "; ")
        println("C\t", name, "\t", c, "\t", v, "\t", round(100v / max(total, 1); digits = 1), "\t", fl, "\t", top)
    end
    if !isempty(jr)
        println("R\t", name, "\t", join(["$(first(l)) $(last(l))" for l in first(sort(collect(jr); by = last, rev = true), 14)], "; "))
    end
    if !isempty(jl)
        println("J\t", name, "\t", join(["$(first(l)) $(last(l))" for l in first(sort(collect(jl); by = last, rev = true), 12)], "; "))
    end
end
function final_prof()
    println("## the whole: ", sum(values(TOT)), " samples")
    for (c, v) in sort(collect(TOT); by = last, rev = true)
        println("T\t", c, "\t", v, "\t", round(100v / sum(values(TOT)); digits = 1))
    end
end
