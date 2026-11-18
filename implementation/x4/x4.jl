# E-270 (X4 of the work plan §8; W-98's gate): what does jl_subtype cost with many
# entries on a common chain? Run on the unified build and on the vanilla control:
#     <tree>/julia --startup-file=no x4.jl <label>
# On vanilla the sets are plain abstract types with no members (the baseline of an
# unrelated pair). On the unified build k sets each hold an entry for
# `AbstractVector{T} where T` (BaseTraits' families on AbstractVector), and a
# set-in-set chain of depth 3 leads to a set at its top. Each question is asked
# through ccall (jl_subtype, jl_isa) so nothing folds; ns per call, the median of
# 7 rounds of 200,000 calls.
using Printf
const unified = isdefined(Core, :MembershipEntry)
label = get(ARGS, 1, unified ? "unified" : "vanilla")
out = joinpath(@__DIR__, "out"); mkpath(out)
io = open(joinpath(out, "$label.txt"), "w")
say(s) = (println(s); println(io, s); flush(io))
say("E-270 $label on $(Base.GIT_VERSION_INFO.commit_short), machine load $(read("/proc/loadavg", String)[1:14])")

open_set!(T) = unified && ccall(:jl_set_open_set, Cvoid, (Any,), T)
declare!(member, set) = unified && (ccall(:jl_declare_membership, Any, (Any, Any, Any, Any, Any),
                                          member, set, @__MODULE__, nothing, :self); true)

# a set declared as @trait does: opened before its binding is published
function mkset(name::Symbol; params::Int = 0, super = Any)
    tvs = [Core.TypeVar(Symbol(:P, i)) for i in 1:params]
    T = Core._abstracttype(@__MODULE__, name, Core.svec(tvs...))
    open_set!(T)
    Core._setsuper!(T, super)
    Core._typebody!(false, T)
    Core.declare_const(@__MODULE__, name, T)
    return getglobal(@__MODULE__, name)
end

subty(a, b) = ccall(:jl_subtype, Cint, (Any, Any), a, b)
isa_(x, t) = ccall(:jl_isa, Cint, (Any, Any), x, t)
function per_call(f, a, b, n = 200_000)
    t0 = time_ns()
    for _ in 1:n
        f(a, b)
    end
    return (time_ns() - t0) / n
end
med(f, a, b) = (v = sort([per_call(f, a, b) for _ in 1:7]); v[4])

mkset(:Unrel)                               # a set nothing joins
abstract type Closed end                    # a closed abstract type
const VI = Vector{Int}
results = Tuple{String,Int,Float64}[]
row(name, k, ns) = (push!(results, (name, k, ns)); say(@sprintf("  %-52s k=%-3d %8.1f ns", name, k, ns)))

prune(on) = unified ? ccall(:jl_set_membership_prune, Cint, (Cint,), on) : 0
let k = 0
    sets = Any[]
    for kk in (0, 1, 10, 50)
        while k < kk
            k += 1
            S = mkset(Symbol(:Fam, k); params = 1)
            declare!(AbstractVector, S)     # AbstractVector{T} where T joins S{?} at every T
            push!(sets, S)
        end
        say("k = $k entries on AbstractVector's chain:")
        for p in (unified ? (1, 0) : (1,))
            prune(p)
            tag = unified ? (p == 1 ? " (pruned)" : " (no pruning)") : ""
            row("Vector{Int} <: Closed (unrelated, closed)" * tag, k, med(subty, VI, Closed))
            row("Vector{Int} <: Unrel (non-member, open)" * tag, k, med(subty, VI, Unrel))
            row("isa([1], Unrel)" * tag, k, med(isa_, [1], Unrel))
            if k > 0
                row("Vector{Int} <: Fam1 (a member)" * tag, k, med(subty, VI, sets[1]))
                row("Vector{Int} <: Fam$k (the last entry)" * tag, k, med(subty, VI, sets[end]))
            end
        end
        prune(1)
    end
end

# a set-in-set chain of depth 3: M ∈ C1 ∈ C2 ∈ C3
mkset(:C3); mkset(:C2); mkset(:C1)
struct M end
declare!(C2, C3); declare!(C1, C2); declare!(M, C1)
say("a set-in-set chain of depth 3:")
row("M <: C3 (through three entries)", 3, med(subty, M, C3))
row("M <: Unrel (non-member)", 3, med(subty, M, Unrel))
row("isa(M(), C3)", 3, med(isa_, M(), C3))
close(io)
