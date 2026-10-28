# W-75: where C's load goes in strict mode. The workload's `using`s under the profiler (1 ms), with strict mode on
# or off by JULIA_TW_STRICT; samples attributed to the frames below by inclusive count.
#     JULIA_TW_STRICT=1|0 julia --project=env_core profile_strict_load.jl   (from experiments/ttfx)
using Profile
Profile.init(n = 10^8, delay = 0.001)
t = @elapsed @profile begin
    using OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock
    using CairoMakie
end
data = Profile.fetch()
lidict = Profile.getdict(data)
frames = Dict(k => [string(f.func) for f in v] for (k, v) in lidict)
files = Dict(k => [string(f.file) for f in v] for (k, v) in lidict)
cnt = Dict{String,Int}(); nsamp = 0; under = Dict{String,Int}(); nunder = 0
stack = Set{String}(); tw = false; gc = false
for x in data
    if x == 0
        if !isempty(stack)
            global nsamp += 1
            for f in stack; cnt[f] = get(cnt, f, 0) + 1; end
            if "jl_restore_package_image_from_stream" in stack
                global nunder += 1
                for f in stack; under[f] = get(under, f, 0) + 1; end
            end
            tw && (cnt["(any TraitWorld frame)"] = get(cnt, "(any TraitWorld frame)", 0) + 1)
        end
        empty!(stack); global tw = false
    else
        for (f, file) in zip(get(frames, x, String[]), get(files, x, String[]))
            push!(stack, f)
            occursin("TraitWorld", file) && (global tw = true)
        end
    end
end
println("L load ", round(t; digits = 2), " s; samples ", nsamp, "; strict ", get(ENV, "JULIA_TW_STRICT", "0"))
for (f, n) in sort!(collect(cnt); by = last, rev = true)[1:min(end, 45)]
    println("L ", lpad(n, 6), "  ", round(100n / nsamp; digits = 1), "%  ", f)
end
println("U under image restore: ", nunder, " samples; frames (inclusive):")
for (f, n) in sort!(collect(under); by = last, rev = true)[1:min(end, 90)]
    n == nunder && continue
    println("U ", lpad(n, 6), "  ", f)
end
