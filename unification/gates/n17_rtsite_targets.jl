# Gate for compiler §9's rule for run-time sites (E-326): while an image is built, a run-time site in
# facts code whose types match one method that specializes on none of the site's abstract arguments
# has that method's instance (its compileable signature, the facts policy) compiled into the image.
# A site whose method specializes on its argument, or whose types match two methods, adds nothing.
# Nothing calls the targets while the image is built: only the caller is compiled. Runs child
# processes on a fresh depot.
include("util.jl")

const ROOT = mktempdir()
const PKGS = joinpath(ROOT, "pkgs")
const DEPOT = joinpath(ROOT, "depot")
mkpath(DEPOT)
mkpath(joinpath(PKGS, "RtS", "src"))
write(joinpath(PKGS, "RtS", "src", "RtS.jl"), """
module RtS
Base.Experimental.@compiler_options facts=true
helper(@nospecialize(x)) = x isa Int ? 1 : 2            # specializes on nothing: its one instance is the target
spec(x) = x isa Int ? 3 : 4                              # specializes on `x`: an instance per type, none held
two(x::Integer) = 5                                      # two methods match `Any`: no target
two(x::AbstractString) = 6
function caller(v::Vector{Any})
    s = 0
    for x in v
        s += helper(x)::Int                              # each call a run-time site: `x` is `Any`
        s += spec(x)::Int
        s += two(x)::Int
    end
    return s
end
precompile(caller, (Vector{Any},))                       # compiles the caller only
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

ok, out, err = child("using RtS")
@assert ok "precompiling RtS: $err"
ok, out, err = child("""
    using RtS
    # the instances with native code that the image brought, before any call: their signatures and policy
    function held(f)
        out = String[]
        for m in methods(f), mi in Base.specializations(m)
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci !== nothing
                if ci.owner === nothing
                    facts = (getfield(ci, :flags, :monotonic)::UInt8 & 0x20) != 0
                    push!(out, string(mi.specTypes.parameters[2], facts ? " facts" : " plain"))
                end
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
        return out
    end
    println("helper ", held(RtS.helper))
    println("spec ", held(RtS.spec))
    println("two ", held(RtS.two))
    println("result ", RtS.caller(Any[1, "a"]))
""")
@assert ok "loading RtS: $err"
@assert occursin("helper [\"Any facts\"]", out) "the image holds helper's one instance, by facts: $out"
@assert occursin("spec String[]", out) "a method that specializes on its argument adds nothing: $out"
@assert occursin("two String[]", out) "a site that matches two methods adds nothing: $out"
@assert occursin("result 21", out) "results: $out"
println("n17_rtsite_targets: OK")
