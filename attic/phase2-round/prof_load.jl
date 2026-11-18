# E-233: where a load goes, by sampling (E-185's experiments/ttfx/loader/prof_load.jl, the packages from the command line;
# TraitWorld's load hooks added to the phases). Samples attributed to the loader's phases (frames by function name, inclusive).
#     julia --project=<env> prof_load.jl CSV,DataFrames,Statistics,Dates
using Profile
Profile.init(n = 10^8, delay = parse(Float64, get(ENV, "PROF_DELAY", "0.0005")))
const PKGS = Symbol.(split(ARGS[1], ","))
Base.cumulative_compile_timing(true)
t = @elapsed @profile for p in PKGS
    Base.require(Main, p)
end
println("P compile in the load ", round(Base.cumulative_compile_time_ns()[1] / 1e9; digits = 3), " s")
data = Profile.fetch(include_meta = false)
const LD = Dict{UInt64,Vector{Base.StackTraces.StackFrame}}()
frames(ip) = get!(() -> Profile.lookup(ip), LD, ip)
phases = ["verify_method_graph", "verify_method", "jl_promote_ci_to_current", "scan_new_methods!", "scan_new_code!",
          "insert_backedges", "jl_restore_package_image_from_file", "jl_restore_incremental", "jl_activate_methods",
          "_include_from_serialized", "register_restored_modules", "run_module_init", "_tryrequire_from_serialized",
          "_methods_by_ftype", "jl_matching_methods", "ml_matches", "jl_insert_methods", "jl_method_table_activate",
          "_on_package_load_callback", "_on_image_methods_hook", "_member_from_record!", "_member_fold_at_load", "_check_member",
          "jl_gc_collect", "ijl_gc_collect", "_gc_collect",
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
