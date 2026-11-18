# C-74's reproducer: a module compiled by facts whose workload runs one closure in a task and one
# directly; it prints the closures' CodeInstances while its image is built and after its load.
module C74Probe
using TraitWorld: @trait_module
@trait_module bounded = false no_pirates = false

function taskforeach(f, items)
    n = length(items)
    next = Threads.Atomic{Int}(1)
    @sync for _ in 1:2
        Threads.@spawn begin
            while true
                i = Threads.atomic_add!(next, 1)
                i > n && break
                f(@inbounds items[i])
            end
        end
    end
    return nothing
end

function intask(v::Vector{Int})
    acc = Threads.Atomic{Int}(0)
    taskforeach(i -> Threads.atomic_add!(acc, v[i]), 1:length(v))
    return acc[]
end

direct(v::Vector{Int}) = sum(map(x -> x + 1, v))

# a closure whose callee gains a more specific method after the workload: its CodeInstance from the
# workload is invalidated, so the image's native compile infers it again
kernel(x::Integer) = x + 1
function intask_later(v::Vector{Int})
    acc = Threads.Atomic{Int}(0)
    taskforeach(i -> Threads.atomic_add!(acc, kernel(v[i])), 1:length(v))
    return acc[]
end

function report(io::IO, when::String)
    for name in names(@__MODULE__; all = true)
        s = string(name)
        startswith(s, "#") || continue
        T = getfield(@__MODULE__, name)
        T isa Type || continue
        for match in Base._methods_by_ftype(Tuple{T, Vararg{Any}}, -1, Base.get_world_counter())
            m = match.method
            m.module === (@__MODULE__) || continue
            for mi in Base.specializations(m)
                ci = isdefined(mi, :cache) ? mi.cache : nothing
                while ci !== nothing
                    fl = getfield(ci, :flags, :monotonic)::UInt8
                    inf = getfield(ci, :inferred, :monotonic)
                    println(io, when, ": ", m.name, " policy ", ccall(:jl_method_policy, Cint, (Any,), m),
                            " facts=", (fl & 0x20) != 0, " image=", (fl & 0x04) != 0,
                            " inferred=", inf === nothing ? "nothing" : nameof(typeof(inf)),
                            " invoke=", getfield(ci, :invoke, :monotonic) != C_NULL, "  ", mi.specTypes)
                    ci = isdefined(ci, :next) ? ci.next : nothing
                end
            end
        end
    end
end

intask([1, 2, 3, 4])
direct([1, 2, 3, 4])
intask_later([1, 2, 3, 4])
kernel(x::Int) = x + 1                       # after the workload: invalidates `intask_later`'s closure
ccall(:jl_generating_output, Cint, ()) != 0 && report(stderr, "build")
end
