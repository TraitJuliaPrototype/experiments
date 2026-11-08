# Gate for compiler C-74 (§2.3, §9): an image keeps the code of a method compiled by facts at its
# policy, whoever compiled it last. A module compiled by facts runs a closure in a task in its
# workload; a method defined after the workload invalidates that closure's code, so the image's
# native compile infers it again: under the closure's own policy, never the compiling interpreter's.
# After the load, every CodeInstance of the module's methods (closures included) is facts. Runs child
# processes on a fresh depot.
include("util.jl")

const ROOT = mktempdir()
const PKGS = joinpath(ROOT, "pkgs")
const DEPOT = joinpath(ROOT, "depot")
mkpath(DEPOT)
mkpath(joinpath(PKGS, "PolC", "src"))
write(joinpath(PKGS, "PolC", "src", "PolC.jl"), """
module PolC
Base.Experimental.@compiler_options facts=true
kernel(x::Integer) = x + 1
function viatask(v::Vector{Int})
    acc = Threads.Atomic{Int}(0)
    t = Threads.@spawn for i in eachindex(v)
        Threads.atomic_add!(acc, kernel(v[i]))
    end
    wait(t)
    return acc[]
end
direct(v::Vector{Int}) = sum(x -> kernel(x), v)
viatask([1, 2, 3])
direct([1, 2, 3])
kernel(x::Int) = x + 1      # after the workload: the callers of `kernel(::Int)` are invalidated
end
""")

const JULIA = Base.julia_cmd()
function child(code)
    env = copy(ENV)
    env["JULIA_DEPOT_PATH"] = DEPOT * ":" * join(DEPOT_PATH[2:end], ":")
    env["JULIA_LOAD_PATH"] = join([PKGS, "@stdlib"], ":")
    cmd = setenv(`$JULIA --startup-file=no -e $code`, env)
    out = IOBuffer(); err = IOBuffer()
    ok = success(pipeline(cmd; stdout = out, stderr = err))
    return ok, String(take!(out)), String(take!(err))
end

ok, out, err = child("using PolC")
@assert ok "precompiling PolC: $err"
ok, out, err = child("""
    using PolC
    plain = String[]; n = 0
    for name in names(PolC; all = true)
        T = getfield(PolC, name)
        T isa Type || T isa Function || continue
        ft = T isa Function ? typeof(T) : T
        for match in Base._methods_by_ftype(Tuple{ft, Vararg{Any}}, -1, Base.get_world_counter())
            m = match.method
            m.module === PolC || continue
            ccall(:jl_method_policy, Cint, (Any,), m) == 1 || continue
            for mi in Base.specializations(m)
                ci = isdefined(mi, :cache) ? mi.cache : nothing
                while ci !== nothing
                    if ci.owner === nothing
                        global n += 1
                        (getfield(ci, :flags, :monotonic)::UInt8 & 0x20) == 0 && push!(plain, string(mi.specTypes))
                    end
                    ci = isdefined(ci, :next) ? ci.next : nothing
                end
            end
        end
    end
    println("facts methods' instances ", n, " plain ", length(plain))
    foreach(println, plain)
    println("result ", PolC.viatask([1, 2, 3]), " ", PolC.direct([1, 2, 3]))
""")
@assert ok "loading PolC: $err"
@assert occursin(r"facts methods' instances [1-9]", out) "the image holds the module's instances: $out"
@assert occursin(" plain 0", out) "every instance of a facts method is facts: $out"
@assert occursin("result 9 9", out) "results: $out"
println("n15_image_policy: OK")
