# E-259 (U9): the cost of one guard of option (e) (open issue 136): a membership read in the caller's
# world, as a branch before a call, against the unguarded call. Plain Julia, no TraitWorld.
#
#     jl --exclusive julia-1.13/julia --startup-file=no experiments/w83/u9/guardcost.jl
#
# The call: `f(x)` at a concrete `S` that is not (yet) a member of an open set `X`; `m0` (the method
# selected now, a fallback) runs; the bounded method `fb` would run once `S ∈ X` is declared in a world
# no later than the caller's. Each loop sums `f(x)` over a vector of 1,000 `S` values.
#
#   plain           s += m0(x)                                    the unguarded call (option (a), or a closed set)
#   cell            a cell per (S, X) holding the membership's min_world (typemax: none), fixed when the
#                   guard is compiled: s += (cell[] <= world ? fb_rt(x)::Float64 : m0(x))
#   cell_fast       the same, the world read only where the cell holds a membership (none here)
#   registry        U8 part B's registry: a Vector of (type, set, min_world), scanned by a @noinline read
#   dict            a per-type table keyed by set (IdDict{Any,IdDict{Any,UInt}}), a @noinline read
#   plain_opaque, cell_opaque   the same with a `@noinline` write to a global in the loop, so that the
#                   cell's load is not hoisted out of the loop (in `cell` LLVM unswitches the loop on it)
#   cell_widened    `cell` without a declared result: the guarded call's result is `Any`, so the sum is
#                   `Any` (a guard that widens)
# `fb_rt` is the bounded method called as a run-time site (`Base.inferencebarrier`): it never runs here.
# Each variant is timed both with `m0` inlined and with `m0` behind `@noinline`.

struct S; a::Float64; end
abstract type X end                      # the open set (membership is the registry's, not subtyping)

@inline m0(x::S) = x.a + 1.0
@noinline m0n(x::S) = x.a + 1.0
fb(x::S) = 2.0 * x.a                     # the bounded method's body
fb_rt(x) = Base.inferencebarrier(fb)(x)  # the guarded branch: a run-time site

# --- registries ---
const CELL = Ref{UInt}(typemax(UInt))                          # the membership S ∈ X: none
const REG = Tuple{Any,Any,UInt}[]                              # U8 part B
for i in 1:20; push!(REG, (Val{i}, X, UInt(1))); end          # 20 other entries before ours
const DICT = IdDict{Any,IdDict{Any,UInt}}()
for i in 1:20; DICT[Val{i}] = IdDict{Any,UInt}(X => UInt(1)); end
DICT[S] = IdDict{Any,UInt}()                                   # S has a table, X not in it

@inline world() = Base.tls_world_age()
@noinline function member_reg(@nospecialize(T), @nospecialize(Y))
    w = world()
    for (t, y, mw) in REG
        t === T && y === Y && mw <= w && return true
    end
    return false
end
@noinline function member_dict(@nospecialize(T), @nospecialize(Y))
    d = get(DICT, T, nothing)
    d === nothing && return false
    mw = get(d, Y, typemax(UInt))
    return mw <= world()
end
@inline member_cell() = CELL[] <= world()
@inline member_cellfast() = (c = CELL[]; c != typemax(UInt) && c <= world())

function plain(v, f)
    s = 0.0
    @inbounds for x in v; s += f(x); end
    return s
end
function cell(v, f)
    s = 0.0
    @inbounds for x in v; s += member_cell() ? fb_rt(x)::Float64 : f(x); end
    return s
end
function cellfast(v, f)
    s = 0.0
    @inbounds for x in v; s += member_cellfast() ? fb_rt(x)::Float64 : f(x); end
    return s
end
function registry(v, f)
    s = 0.0
    @inbounds for x in v; s += member_reg(S, X) ? fb_rt(x)::Float64 : f(x); end
    return s
end
function dict(v, f)
    s = 0.0
    @inbounds for x in v; s += member_dict(S, X) ? fb_rt(x)::Float64 : f(x); end
    return s
end
function cellwidened(v, f)
    s = 0.0
    @inbounds for x in v; s += member_cell() ? fb_rt(x) : f(x); end
    return s
end

# with a write the compiler cannot see through in the loop: the cell's load cannot be hoisted out
const SINK = Ref{Any}(nothing)
@noinline sink!(x) = (SINK[] = x; nothing)
function plain_opaque(v, f)
    s = 0.0
    @inbounds for x in v; s += f(x); sink!(x); end
    return s
end
function cell_opaque(v, f)
    s = 0.0
    @inbounds for x in v; s += member_cell() ? fb_rt(x)::Float64 : f(x); sink!(x); end
    return s
end

const V = [S(Float64(i)) for i in 1:1000]
const VARIANTS = (("plain", plain), ("cell", cell), ("cell_fast", cellfast), ("registry", registry), ("dict", dict), ("cell_widened", cellwidened), ("plain_opaque", plain_opaque), ("cell_opaque", cell_opaque))

function timeit(g, f; samples = 2001)
    g(V, f); g(V, f)
    ts = Vector{Float64}(undef, samples)
    for k in 1:samples
        t = time_ns(); r = g(V, f); ts[k] = (time_ns() - t) / length(V)
        r == 0.0 && error("unexpected")
    end
    sort!(ts)
    return ts[(samples + 1) ÷ 2], ts[max(1, samples ÷ 10)], ts[samples - samples ÷ 10], @allocated(g(V, f)) / length(V)
end

println("U9 guard cost: julia ", Base.GIT_VERSION_INFO.commit_short, ", load ", read("/proc/loadavg", String)[1:14], ", ", Threads.nthreads(), " thread(s)")
println("ns per call, median (p10, p90) over 2001 loops of 1,000 calls; bytes allocated per call")
for (mname, mf) in (("m0 inlined", m0), ("m0 @noinline", m0n))
    println("-- ", mname)
    for (name, g) in VARIANTS
        med, p10, p90, al = timeit(g, mf)
        println("  ", rpad(name, 14), lpad(string(round(med; digits = 3)), 8), "  (", round(p10; digits = 3), ", ", round(p90; digits = 3), ")  ", al, " B")
    end
end
# the code of one guarded loop, to show the guard is a load, a world read and a branch
using InteractiveUtils
if get(ENV, "U9_SHOW_CODE", "0") == "1"
    code_llvm(stdout, cell, Tuple{Vector{S}, typeof(m0)}; debuginfo = :none)
end
