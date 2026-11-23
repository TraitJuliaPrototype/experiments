# W-171, fourth part (E-545; compiler C-168): does a task run, in the new world, code an image's activation ends? A
# package `QB` holds a set `X` with methods at it (`g(::Any)`, `g(::X)`, and NH more functions at `X` so that a
# membership's walk has work), and NM types `S1`…`SNM`; package `Mi` declares `Si in X` in its image. In a child
# process with three threads, `q(Si())` (a call of `g`) is compiled for every `Si` before any `Mi` is loaded; two
# threads ask `q(Si())` in the world they read from the counter and the runtime's own answer (`jl_isa`) in that world,
# while the third loads M1…MNM one after another. A wrong answer is one where the compiled code answers `:Any` in a
# world where `Si` is a member: code the activation ends, run in its world. Asked again after the loads, in the same
# world: whether it was transient or kept.
#     julia --project=experiments/implementation image_thread_race.jl [NM=40] [NH=200] [--keep]
const NM = length(ARGS) >= 1 && !startswith(ARGS[1], "--") ? parse(Int, ARGS[1]) : 40
const NH = length(ARGS) >= 2 && !startswith(ARGS[2], "--") ? parse(Int, ARGS[2]) : 200
const KEEP = "--keep" in ARGS

function write_pkg(dir, name, body)
    mkpath(joinpath(dir, name, "src"))
    write(joinpath(dir, name, "src", "$name.jl"), body)
end

const CHILD = raw"""
using QB
const NM = length(QB.SS)
fresh(x) = ccall(:jl_isa, Cint, (Any, Any), x, QB.X) != 0 ? :X : :Any
const qs = [(@eval $(Symbol(:q_, i))(x) = QB.g(x)) for i in 1:NM]   # one caller per member, each compiled for its member
for i in 1:NM; qs[i](QB.SS[i]()); end
const stop = Threads.Atomic{Bool}(false)
const wrongs = Tuple{UInt,Int,Symbol,Symbol}[]
const lk = ReentrantLock()
const n = Threads.Atomic{Int}(0)
const loading = Threads.Atomic{Int}(0)
function reader()
    while !stop[]
        i = loading[]
        i == 0 && (yield(); continue)
        w = Base.get_world_counter()
        x = QB.SS[i]()
        a = Base.invoke_in_world(w, qs[i], x); r = Base.invoke_in_world(w, fresh, x)
        Threads.atomic_add!(n, 1)
        a == r || lock(() -> push!(wrongs, (w, i, a, r)), lk)
    end
end
function writer()
    for i in 1:NM
        loading[] = i
        c = n[]; while n[] < c + 2; yield(); end
        Base.require(Main, Symbol("M", i))
        c = n[]; while n[] < c + 2; yield(); end
    end
    stop[] = true
end
r1 = Threads.@spawn reader(); r2 = Threads.@spawn reader(); wt = Threads.@spawn writer()
wait(wt); wait(r1); wait(r2)
kept = count(((w, i, a, r),) -> Base.invoke_in_world(w, qs[i], QB.SS[i]()) != Base.invoke_in_world(w, fresh, QB.SS[i]()), wrongs)
ok = all(i -> qs[i](QB.SS[i]()) === :X, 1:NM)
println("image_thread_race: ", NM, " images, ", n[], " checks, ", length(wrongs), " wrong, of them kept when asked again: ",
        kept, "; after the loads every caller answers :X: ", ok,
        isempty(wrongs) ? "" : ", e.g. $(first(wrongs)), in $(length(unique(first.(wrongs)))) worlds")
"""

function main()
    root = mktempdir(; cleanup = !KEEP)
    pk = joinpath(root, "pkgs"); depot = joinpath(root, "depot"); mkpath(depot)
    io = IOBuffer()
    println(io, "module QB\nusing Traits\n@trait X\ng(::Any) = :Any\ng(::X) = :X")
    for k in 1:NH; println(io, "h$k(::Any) = 0\nh$k(::X) = $k"); end
    for i in 1:NM; println(io, "struct S$i end"); end
    println(io, "const SS = (", join(("S$i" for i in 1:NM), ", "), ",)\nend")
    write_pkg(pk, "QB", String(take!(io)))
    for i in 1:NM
        write_pkg(pk, "M$i", "module M$i\nusing Traits, QB\nTraits.declare_membership(QB.S$i, QB.X, @__MODULE__)\nend")
    end
    env = copy(ENV)
    env["JULIA_DEPOT_PATH"] = depot * ":" * join(DEPOT_PATH[2:end], ":")
    env["JULIA_LOAD_PATH"] = join([pk, dirname(dirname(@__DIR__)), "@stdlib"], ":")
    env["JULIA_PKG_PRECOMPILE_AUTO"] = "0"
    jl = Base.julia_cmd()
    t0 = time()
    # the images, made first in one process (each in a worker of its own)
    pre = "using QB; " * join(("Base.compilecache(Base.identify_package(\"M$i\"))" for i in 1:NM), "; ")
    run(setenv(`$jl --startup-file=no -e $pre`, env))
    out = read(setenv(`$jl -t 3 --startup-file=no -e $CHILD`, env), String)
    print(out)
    println("image_thread_race: Julia ", Base.GIT_VERSION_INFO.commit_short, ", NH ", NH, ", ", round(time() - t0; digits = 1), " s")
    KEEP ? println("kept: ", root) : rm(root; recursive = true, force = true)
end
main()
