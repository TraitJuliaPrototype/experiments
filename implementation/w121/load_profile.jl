# E-286 (W-121, phase 1): where loading spends its time. For each package in ARGS, in order, in this process:
# the load timed whole, or (with W121_PROFILE=1) profiled with C frames: the main thread's samples that are not
# sleeping, each attributed to the class of highest priority on its stack (CLASSES' order).
# Usage: julia --project=<env> load_profile.jl Pkg1 Pkg2 ...
using Profile
# W121_CALLBACKS_LAST=1 (E-292): the package callbacks last, so the extensions' loads inside them are split by the classes below
const CLASSES0 = [
    ("activation: the dispatch walk", ["jl_membership_dispatch_walk"]),
    ("activation: the ambiguity report", ["jl_membership_ambiguity_report"]),
    ("activation: the cells", ["jl_membership_update_cells"]),
    ("activation: the rest", ["jl_activate_memberships", "jl_memberships_activated"]),
    ("package callbacks", ["run_package_callbacks"]),
    ("__init__", ["run_module_init", "register_restored_modules"]),
    ("validation", ["verify_method_graph", "jl_verify", "verify_call", "_insert_backedges", "insert_backedges"]),
    ("inference/compile", ["typeinf_ext", "jl_type_infer", "jl_compile_method_internal", "jl_compile_codeinst", "jl_emit_codeinst"]),
    ("image restore", ["jl_restore_package_image", "jl_restore_incremental", "ijl_restore_package_image_from_file"]),
]
const CLASSES = get(ENV, "W121_CALLBACKS_LAST", "0") == "1" ? [filter(c -> c[1] != "package callbacks", CLASSES0); filter(c -> c[1] == "package callbacks", CLASSES0)] : CLASSES0
function classify_samples()
    data, lidict = Profile.retrieve()
    counts = Dict{String,Int}(); total = 0
    # a block: frames..., threadid, taskid, cpu clock, sleep state, 0, 0 (Profile's layout)
    start = 1; n = length(data); i = 3
    while i <= n
        if data[i] == 0 && data[i-1] == 0 && data[i-2] in 1:3
            tid = data[i-5]; sleeping = data[i-2] != 1
            frames = @view data[start:i-6]
            start = i + 1
            if tid == 1 && !sleeping && !isempty(frames)
                total += 1
                # the class of highest priority (CLASSES' order) anywhere on the stack: activation inside an
                # image's restore counts as activation, inference under the callbacks as the callbacks
                best = length(CLASSES) + 1
                for ip in frames, fr in get(lidict, ip, Base.StackTraces.StackFrame[])
                    name = string(fr.func)
                    for (k, (c, keys)) in enumerate(CLASSES)
                        k < best && any(key -> occursin(key, name), keys) && (best = k)
                    end
                end
                cls = best <= length(CLASSES) ? CLASSES[best][1] : "other"
                counts[cls] = get(counts, cls, 0) + 1
            end
            i += 3
            continue
        end
        i += 1
    end
    return counts, total
end
for p in ARGS
    sym = Symbol(p)
    if get(ENV, "W121_PROFILE", "0") == "1"
        Profile.clear(); Profile.init(n = 10^7, delay = 0.0005)
        t = @elapsed @profile Core.eval(Main, :(using $sym))
        counts, total = classify_samples()
        parts = join(["$(k) $(round(100 * v / max(total, 1), digits = 1))%" for (k, v) in sort(collect(counts), by = x -> -x[2])], ", ")
        println("P ", p, " ", round(t, digits = 3), " s (profiled), ", total, " samples | ", parts)
    else
        t = @elapsed Core.eval(Main, :(using $sym))
        println("L ", p, " ", round(t, digits = 3), " s")
    end
end
