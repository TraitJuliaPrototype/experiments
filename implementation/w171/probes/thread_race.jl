# W-171, third part (E-544): the thread mode's wrong answers. One thread asks `g(S())` compiled for `S` (methods at
# `Any` and at `X`) in the world it reads; another declares and takes back `S in X` (mode `member`), or defines and
# deletes a method `g(::S)` (mode `method`, plain Julia's own case). A wrong answer is asked again in the same world
# after the writer ends: whether the stale code stays (`kept`) or was transient.
#     julia -t 3 --project=experiments/implementation thread_race.jl [member|method] [rounds]
using Traits
const MODE = isempty(ARGS) ? "member" : ARGS[1]
const ROUNDS = length(ARGS) < 2 ? 2000 : parse(Int, ARGS[2])
@trait X
struct S end
g(::Any) = :Any
MODE == "member" && (g(::X) = :X)
q(x) = g(x)
fresh(x) = MODE == "member" ? (ccall(:jl_isa, Cint, (Any, Any), x, X) != 0 ? :X : :Any) :
           (first(Base._methods_by_ftype(Tuple{typeof(g), S}, -1, Base.tls_world_age())).method.sig == Tuple{typeof(g), S} ? :S : :Any)
const stop = Threads.Atomic{Bool}(false)
const wrongs = Tuple{UInt,Symbol,Symbol}[]
const lk = ReentrantLock()
const n = Threads.Atomic{Int}(0)
function reader()
    while !stop[]
        w = Base.get_world_counter()
        a = Base.invoke_in_world(w, q, S()); r = Base.invoke_in_world(w, fresh, S())
        Threads.atomic_add!(n, 1)
        a == r || lock(() -> push!(wrongs, (w, a, r)), lk)
    end
end
function writer()
    for i in 1:ROUNDS
        if MODE == "member"
            Traits.declare_membership(S, X, @__MODULE__)
            ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), S, X, @__MODULE__)
        else
            @eval g(::S) = :S
            Base.delete_method(only(filter(m -> m.sig == Tuple{typeof(g), S}, methods(g).ms)))
        end
        c = n[]; while n[] < c + 2; yield(); end
    end
    stop[] = true
end
r1 = Threads.@spawn reader(); r2 = Threads.@spawn reader(); wt = Threads.@spawn writer()
wait(wt); wait(r1); wait(r2)
kept = count(((w, a, r),) -> Base.invoke_in_world(w, q, S()) != Base.invoke_in_world(w, fresh, S()), wrongs)
println("thread_race $MODE: ", n[], " checks, ", length(wrongs), " wrong, of them kept when asked again: ", kept,
        isempty(wrongs) ? "" : ", e.g. $(first(wrongs)), in $(length(unique(first.(wrongs)))) worlds of $(ROUNDS * 2)")
