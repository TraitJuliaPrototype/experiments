# E-403, a diagnostic: which callers construct `Dynamic` (Core's checked constructor) in step d's steady state.
#   NDW_API=ports NDW_STACK=ports NDW_PASSES=again julia --project=<env> --threads=1 who_boxes.jl   (from ndport/)
include(joinpath(pwd(), "scripts", "workload.jl"))
c = NDW.step_c(nw; γ = 0.1)
NDW.step_d(nw, c.s)
using Profile
Profile.init(n = 10^7, delay = 0.0005)
@profile for i in 1:3; NDW.step_d(nw, c.s); end
data, ldict = Profile.retrieve()
counts = Dict{String,Int}()
bt = UInt64[]
function flush!(bt)
    frames = Any[]
    for ip in bt
        for fr in get(ldict, ip, Base.StackTraces.StackFrame[])
            push!(frames, fr)
        end
    end
    i = findfirst(fr -> fr.func === :Dynamic && endswith(string(fr.file), "boot.jl"), frames)
    i === nothing && return
    key = join([string(fr.func, " ", basename(string(fr.file)), ":", fr.line) for fr in frames[i+1:min(end, i + 4)]], " <- ")
    counts[key] = get(counts, key, 0) + 1
end
for x in data
    if x == 0; flush!(bt); empty!(bt); else push!(bt, x); end
end
for (k, n) in sort(collect(counts); by = last, rev = true)[1:min(end, 8)]
    println("B ", n, "  ", k)
end
