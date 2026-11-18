# E-388 (W-145, part 9): where a session's time goes. A session file is cut into phases at lines
# `#@ name`; each phase is evaluated at top level, as at a prompt, under the profiler (0.5 ms), in
# this one process. The profiler slows a phase (2 to 4 times where the stacks are deep); PROF=0 gives
# the phases' times without it, and the shares are read against those. A phase whose name starts with `_` runs unprofiled (set-up).
# Every sample of the main thread that is not sleeping is given to one class: the first of CLASSES
# with a function on its stack. Per class: its share, how many of its samples have inference, code
# generation, subtyping, a membership query or the collector on the stack, and its top leaves.
#     julia --project=<env> prof.jl <session.jl> [args of the session…]
using Profile
const CLASSES = [
    ("membership walk",        ["jl_membership_dispatch_walk"]),
    ("a method's activation",  ["invalidate_code_instance", "invalidate_backedges", "jl_method_table_disable", "jl_method_table_activate"]),
    ("membership activation",  ["jl_activate_memberships", "jl_memberships_activated", "jl_membership_update_cells", "jl_membership_ambiguity_report", "jl_declare_membership"]),
    ("definition-time check",  ["jl_call_definition_hook"]),
    ("member check",           ["jl_member_queue_drain", "jl_member_note_use", "check_first_use"]),
    ("package callbacks",      ["run_package_callbacks"]),
    ("image validation",       ["verify_method_graph", "verify_call", "insert_backedges", "jl_verify"]),
    ("image restore",          ["jl_restore_package_image", "jl_restore_incremental", "_include_from_serialized"]),
    ("compiling while inferring", String[]),   # code compiled below an inference frame (the compiler's own, a generator, a call evaluated): see `class_of`
    ("inference",              ["typeinf", "jl_type_infer"]),
    ("code generation",        ["jl_emit_", "jl_compile_codeinst", "jl_generate_fptr", "llvm", "JuliaOJIT", "jl_add_to_ee", "jl_compile_method_internal"]),
    ("method lookup",          ["ml_matches", "jl_mt_assoc_by_type", "jl_matching_methods", "jl_typemap_", "jl_lookup_generic", "jl_gf_invoke_lookup"]),
    ("lowering and parsing",   ["jl_expand", "jl_lower", "fl_applyn", "jl_parse", "JuliaLowering", "JuliaSyntax", "jl_fl_"]),
    ("definitions",            ["jl_method_def", "jl_new_datatype", "jl_declare_const"]),
    ("loading, the rest",      ["_require", "__require", "_tryrequire"]),
    ("collector",              ["jl_gc_collect", "gc_mark", "gc_sweep"]),
]
const FLAGS = [("inf", ["typeinf", "jl_type_infer"]), ("gen", ["jl_emit_", "jl_compile_codeinst", "llvm", "JuliaOJIT"]),
               ("sub", ["subtype", "jl_type_intersection", "intersect"]), ("mem", ["jl_subtype_via_membership", "jl_membership_holds_at", "jl_membership_entries_for", "jl_type_has_memberships", "jl_membership_world"]),
               ("gc", ["jl_gc_collect", "gc_mark", "gc_sweep"])]
const NESTED = ["jl_compile_method_internal", "jl_generate_fptr", "jl_emit_", "jl_compile_codeinst"]
const INFC = "jl_type_infer"
hit(name, keys) = any(k -> occursin(k, name), keys)
# names leaf first
function class_of(names)
    best = length(CLASSES) + 1
    for nm in names, (k, (_, keys)) in enumerate(CLASSES)
        k < best && hit(nm, keys) && (best = k)
    end
    if best in (10, 11)      # inference or code generation: is an outer inference running?
        outer = findlast(nm -> occursin(INFC, nm), names)
        if outer !== nothing && any(i -> hit(names[i], NESTED), 1:outer-1)
            best = 9
        end
    end
    best > length(CLASSES) && return "the work itself"
    c = CLASSES[best][1]
    if best in 4:6           # a check or a hook: what it does
        c *= any(nm -> hit(nm, NESTED) || hit(nm, FLAGS[2][2]), names) ? ": compiling its own code" :
             any(nm -> hit(nm, FLAGS[1][2]), names) ? ": inferring" : ": the rest"
    end
    return c
end
leafname(s) = startswith(s, "_Z") ? "LLVM (C++)" : s in ("_int_malloc", "_int_free", "malloc", "free", "cfree", "malloc_consolidate", "unlink_chunk.isra.0") ? "malloc" :
              s in ("syscall", "read", "__open64", "access", "__open64_nocancel", "fstatfs", "__mmap64", "stat64", "__GI___fstatat64", "close", "__close_nocancel", "pread64") ? "file system calls" : first(s, 40)
function report(name, t)
    data, lidict = Profile.retrieve()
    cache = Dict{UInt64,Vector{String}}()
    cls = Dict{String,Int}(); flg = Dict{String,Vector{Int}}(); leaves = Dict{String,Dict{String,Int}}(); total = 0
    start = 1; n = length(data); i = 3
    while i <= n
        if data[i] == 0 && data[i-1] == 0 && data[i-2] in 1:3
            tid = data[i-5]; sleeping = data[i-2] != 1
            frames = @view data[start:i-6]; start = i + 1
            if tid == 1 && !sleeping && !isempty(frames)
                total += 1
                names = String[]
                for ip in frames
                    append!(names, get!(() -> String[string(f.func) for f in get(lidict, ip, Base.StackTraces.StackFrame[])], cache, ip))
                end
                c = class_of(names)
                cls[c] = get(cls, c, 0) + 1
                f = get!(() -> zeros(Int, length(FLAGS)), flg, c)
                for (k, (_, keys)) in enumerate(FLAGS); any(nm -> hit(nm, keys), names) && (f[k] += 1); end
                lf = isempty(names) ? "?" : leafname(names[1])
                d = get!(() -> Dict{String,Int}(), leaves, c); d[lf] = get(d, lf, 0) + 1
            end
            i += 3
        else
            i += 1
        end
    end
    println("## ", name, ": ", round(1000t; digits = 1), " ms, ", total, " samples")
    for (c, v) in sort(collect(cls); by = last, rev = true)
        sh = 100v / max(total, 1)
        sh < 1 && continue
        f = flg[c]
        fl = join(["$(FLAGS[k][1]) $(round(Int, 100f[k] / v))" for k in eachindex(FLAGS) if f[k] > 0], ", ")
        top = join(["$(first(l)) $(round(Int, 100last(l) / v))" for l in first(sort(collect(leaves[c]); by = last, rev = true), 5)], "; ")
        println("  ", rpad(c, 46), lpad(round(sh; digits = 1), 5), " %  ", lpad(round(Int, 1000t * v / max(total, 1)), 5), " ms | of it % ", fl, " | leaves % ", top)
    end
end
function phases(file)
    out = Pair{String,String}[]; name = "_head"; buf = IOBuffer()
    for l in eachline(file)
        if startswith(l, "#@ ")
            push!(out, name => String(take!(buf))); name = strip(l[4:end])
        else
            println(buf, l)
        end
    end
    push!(out, name => String(take!(buf)))
    return out
end
const SESSION = abspath(popfirst!(ARGS))
const OFF = get(ENV, "PROF", "1") == "0"       # PROF=0: the phases' times without the profiler
Profile.init(n = 3 * 10^7, delay = 0.0005)
redirect_stdout(devnull) do; @profile sum(rand(10)); end; Profile.clear()     # the profiler's own first use
for (name, text) in phases(SESSION)
    isempty(strip(text)) && continue
    if startswith(name, "_")
        include_string(Main, text, SESSION)
    elseif OFF
        t = @elapsed redirect_stdout(devnull) do; include_string(Main, text, SESSION); end
        println("## ", name, ": ", round(1000t; digits = 1), " ms unprofiled")
    else
        Profile.clear()
        t = @elapsed redirect_stdout(devnull) do
            @profile include_string(Main, text, SESSION)
        end
        report(name, t)
    end
end
