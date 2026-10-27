# E-185: where the load's validation goes, by sampling: the workload's `using` in one session under the profiler,
# samples attributed to the loader's phases (frames by function name, inclusive).
#     julia --project=env_up loader/prof_load.jl
using Profile
Profile.init(n = 10^8, delay = 0.0005)
t = @elapsed @profile begin
    using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock
    using CairoMakie
end
data = Profile.fetch(include_meta = false)
const LD = Dict{UInt64,Vector{Base.StackTraces.StackFrame}}()
frames(ip) = get!(() -> Profile.lookup(ip), LD, ip)
phases = ["verify_method_graph", "verify_method", "jl_promote_ci_to_current", "scan_new_methods!", "scan_new_code!",
          "insert_backedges", "jl_restore_package_image_from_file", "jl_restore_incremental", "jl_activate_methods",
          "_include_from_serialized", "register_restored_modules", "run_module_init", "_tryrequire_from_serialized",
          "_methods_by_ftype", "jl_matching_methods", "ml_matches", "jl_insert_methods", "jl_method_table_activate",
          "_typeinf", "typeinf", "jl_compile_method_internal", "stale_cachefile", "find_package", "locate_package"]
function tally(data, phases)
    counts = Dict{String,Int}(p => 0 for p in phases)
    nsamples = 0
    cur = Set{String}()
    for ip in data
        if ip == 0
            nsamples += 1
            for p in cur; counts[p] += 1; end
            empty!(cur)
            continue
        end
        for fr in frames(ip)
            n = string(fr.func)
            n in phases && push!(cur, n)
        end
    end
    return counts, nsamples
end
counts, nsamples = tally(data, phases)
println("P load ", round(t; digits = 3), " s, samples ", nsamples, " (", round(t / max(nsamples, 1) * 1e3; digits = 3), " ms each)")
for p in phases
    counts[p] > 0 && println("P ", rpad(p, 40), lpad(counts[p], 7), "  ", round(100 * counts[p] / max(nsamples, 1); digits = 1), "%")
end
# every function's inclusive share, the top 45
function alltally(data)
    c = Dict{String,Int}(); cur = Set{String}(); n = 0
    for ip in data
        if ip == 0
            n += 1; for f in cur; c[f] = get(c, f, 0) + 1; end; empty!(cur); continue
        end
        for fr in frames(ip); push!(cur, string(fr.func, " @", basename(string(fr.file)))); end
    end
    return c, n
end
allc, alln = alltally(data)
for (f, k) in sort!(collect(allc); by = last, rev = true)[1:min(end, 45)]
    println("Q ", lpad(round(100 * k / alln; digits = 1), 5), "%  ", f)
end
