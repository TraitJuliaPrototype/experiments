# E-267 (X6 of the work plan §8; the user, 2026-11-06: "Adopt, keys as optional is approved. Run the X now"):
# is `Callable` by a memoized method-table query inside subtyping cheap and safe (draft compiler §7.4)?
# Emulated in plain Julia on today's build:
#   (1) cost: the query (`jl_gf_invoke_lookup_worlds`, which is `hasmethod` with its world range) per
#       (F, A) for 1,000 closure types, a miss and a memo hit, against `isa` and a plain `<:`;
#       and whether the memo needs method insertion to lower it;
#   (2) a query that reaches itself: two functions whose methods take arguments bounded by `Callable`,
#       queried in both orders under the draft's rule ("a query that reaches itself again answers no",
#       memoized), against the least fixed point and against a memo that keeps no result computed under
#       an assumption (Rust's provisional cache).
# Part (3), the runtime's contexts, is read in the C source; see the README.
#     julia --startup-file=no x6.jl
using Printf
const OUT = get(ENV, "X6_OUT", joinpath(@__DIR__, "out")); mkpath(OUT)
io = open(joinpath(OUT, "x6.txt"), "w")
say(s) = (println(s); println(io, s); flush(io))
say("E-267 on $(Base.GIT_VERSION_INFO.commit_short), $(Threads.nthreads()) threads, machine load $(read("/proc/loadavg", String)[1:14])")

# ---------------- (1) cost ----------------
module Fs end
const N = 1000
const fs = [Core.eval(Fs, :(x -> x + $k)) for k in 1:N]
@assert length(unique(typeof.(fs))) == N
const A = Tuple{Int}
const tts = [Tuple{typeof(f), Int} for f in fs]             # the query's signature per closure type

@inline function query(@nospecialize(tt), w::UInt)
    mn = Ref{UInt}(typemin(UInt)); mx = Ref{UInt}(typemax(UInt))
    m = ccall(:jl_gf_invoke_lookup_worlds, Any, (Any, Any, UInt, Ptr{UInt}, Ptr{UInt}), tt, nothing, w, mn, mx)
    return (m !== nothing, mn[], mx[])
end
const MEMO = IdDict{Any,Tuple{Bool,UInt,UInt}}()
@inline function member(@nospecialize(tt), w::UInt)
    r = get(MEMO, tt, nothing)
    if r !== nothing && r[2] <= w <= r[3]
        return r[1]
    end
    r = query(tt, w)
    MEMO[tt] = r
    return r[1]
end

w = Base.get_world_counter()
# the first query per closure type (cold), one by one
cold = Float64[]
for tt in tts
    t0 = time_ns(); query(tt, w); push!(cold, (time_ns() - t0))
end
# a miss, warm: the query again, 200 times per type
function per_call(f, xs, reps)
    t0 = time_ns()
    for _ in 1:reps, x in xs
        f(x)
    end
    return (time_ns() - t0) / (reps * length(xs))
end
miss = [per_call(tt -> query(tt, w), tts, 200) for _ in 1:5]
foreach(tt -> member(tt, w), tts)                           # fill the memo
hit = [per_call(tt -> member(tt, w), tts, 2000) for _ in 1:5]
isa_ = [per_call(f -> f isa Function, fs, 20000) for _ in 1:5]
sub = [per_call(tt -> (tt.parameters[1] <: Function), tts, 2000) for _ in 1:5]
med(v) = sort(v)[cld(length(v), 2)]
say("(1) cost per call, $(N) closure types, A = $(A); medians of 5 rounds (ns):")
say(@sprintf("    the query, first call per type (cold): median %.0f, 90th percentile %.0f", med(cold), sort(cold)[ceil(Int, 0.9N)]))
say(@sprintf("    the query, warm (a memo miss):           %.1f", med(miss)))
say(@sprintf("    a memo hit (IdDict, world range checked): %.1f", med(hit)))
say(@sprintf("    `<:` Function on the closure's type:     %.1f", med(sub)))
say(@sprintf("    `isa` Function:                          %.1f", med(isa_)))
say("    E-256's entry today: 80-96 ns (the registry row)")

# does the memo need method insertion to lower it? A function with no method at A, then one.
function gtest end
gtest(x::Float64) = 1
tt = Tuple{typeof(gtest), Int}
w1 = Base.get_world_counter(); r1 = query(tt, w1); MEMO[tt] = r1
Core.eval(Main, :(unrelated_x6(x::Int) = 1))                # a method of another function
w2 = Base.get_world_counter(); r2 = query(tt, w2)
Core.eval(Main, :(gtest(x::Int) = 2))                       # now gtest has a method at A
w3 = Base.get_world_counter(); r3 = query(tt, w3)
stale = (MEMO[tt][2] <= w3 <= MEMO[tt][3]) && MEMO[tt][1] != r3[1]
say("    the memo's range: at world $(w1) member=$(r1[1]) valid $(r1[2])..$(r1[3] == typemax(UInt) ? "∞" : r1[3]); " *
    "after another function's method (world $(w2)) the query gives the same range: $(r2[2:3] == r1[2:3]); " *
    "after `gtest(::Int)` (world $(w3)) member=$(r3[1]), and the memo entry from world $(w1) still claims world $(w3) " *
    "with the old answer: $(stale). So method insertion must lower the memo, as the draft says: a walk of the memo per new method of F.")

# ---------------- (2) a query that reaches itself ----------------
# A tiny world: function types as symbols; a method's arguments bounded by a Julia type, by `:Function`
# (any function), or by `CB(As)`, `Callable{Tuple{As...}}`. member(F, As): F has a method whose bounds
# all hold at As. In Julia:
#     function p end; function q end
#     p(x::Callable{Tuple{typeof(p)}}) = 1      # m1
#     p(x::Function) = 2                       # m2
#     q(y::Callable{Tuple{typeof(q)}}) = 3
# a = typeof(p) <: Callable{Tuple{typeof(q)}}: is p callable at q? m1 needs q callable at p (b); m2 holds.
# b = typeof(q) <: Callable{Tuple{typeof(p)}}: is q callable at p? q's method needs p callable at q (a).
# The least fixed point: a = true (m2), so b = true: `q(p)` has a method and runs (3).
struct CB; As::Vector{Any}; end
const METHODS = Dict{Symbol,Vector{Vector{Any}}}(
    :p => [Any[CB(Any[:p])], Any[:Function]],
    :q => [Any[CB(Any[:q])]])
holds(arg, bound, m!) = bound isa CB ? (arg isa Symbol && m!(arg, bound.As)) :
                        bound === :Function ? arg isa Symbol : (arg isa Type && arg <: bound)
anymethod(F, As, m!) = any(sig -> length(sig) == length(As) && all(i -> holds(As[i], sig[i], m!), eachindex(As)), METHODS[F])

# the draft's rule: memoized; a query that reaches itself again answers no
function draft_member(memo, inprog)
    function m!(F, As)
        key = (F, As)
        haskey(memo, key) && return memo[key]
        key in inprog && return false
        push!(inprog, key)
        r = anymethod(F, As, m!)
        delete!(inprog, key)
        memo[key] = r
        return r
    end
end
# a provisional cache: a result that read an assumption is not kept until its cycle's head is final
function provisional_member(memo)
    inprog = Dict{Any,Int}(); stack = Any[]; low = Ref(typemax(Int))
    function m!(F, As)
        key = (F, As)
        haskey(memo, key) && return memo[key]
        if haskey(inprog, key)
            low[] = min(low[], inprog[key]); return false
        end
        depth = length(stack) + 1; inprog[key] = depth; push!(stack, key)
        saved = low[]; low[] = typemax(Int)
        r = anymethod(F, As, m!)
        pop!(stack); delete!(inprog, key)
        if low[] >= depth          # read no assumption above this query: final
            memo[key] = r
            low[] = saved
        else
            low[] = min(saved, low[])
        end
        return r
    end
end
# the least fixed point, by iteration from "no"
function lfp()
    keys_ = [(:p, Any[:q]), (:q, Any[:p]), (:p, Any[:p]), (:q, Any[:q])]
    val = Dict(k => false for k in keys_)
    changed = true
    while changed
        changed = false
        for k in keys_
            v = anymethod(k[1], k[2], (F, As) -> get(val, (F, As), false))
            v != val[k] && (val[k] = v; changed = true)
        end
    end
    val
end
L = lfp()
say("(2) a query that reaches itself (p(x::Callable{Tuple{typeof(p)}}), p(x::Function), q(y::Callable{Tuple{typeof(q)}})):")
say("    the least fixed point: a = p callable at q: $(L[(:p, Any[:q])]); b = q callable at p: $(L[(:q, Any[:p])])")
for (name, mk) in (("the draft's rule (answers no, memoized)", () -> draft_member(Dict{Any,Bool}(), Set{Any}())),
                   ("a provisional cache", () -> provisional_member(Dict{Any,Bool}())))
    m1 = mk(); a1 = m1(:p, Any[:q]); b1 = m1(:q, Any[:p])
    m2 = mk(); b2 = m2(:q, Any[:p]); a2 = m2(:p, Any[:q])
    say("    $(name): a first → a=$(a1), b=$(b1); b first → b=$(b2), a=$(a2)" *
        (a1 == a2 && b1 == b2 ? "  (the same in both orders)" : "  (DEPENDS ON THE ORDER)"))
end
close(io)
