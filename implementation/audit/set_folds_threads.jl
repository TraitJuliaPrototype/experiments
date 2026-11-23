# The set-folds report's thread mode (W-171, E-544): a smoke test. Two threads ask compiled questions about a set
# while a third declares and takes back the membership they are about, for a fixed number of rounds. Each answer is
# compared with the runtime's own answer asked afresh (`ccall`) in the same world, the world read once per check.
# It counts wrong answers and ends; a crash ends the process.
#
#     julia -t 3 --project=experiments/implementation experiments/implementation/audit/set_folds_threads.jl [rounds]
#
# Questions: `S <: X`, `x isa X`, `(x::X; true)`, `new` of a struct whose field is typed `X`, a store into a field typed
# `X`, `g(x)` with methods at `Any` and at `X`, `applicable(h, x)` with a method at `X` only, each compiled for the
# member's type and once at a set (`@nospecializeinfer`, for the member of a second set that joins `X`).

using Traits

const ROUNDS = isempty(ARGS) ? 1000 : parse(Int, ARGS[1])
Threads.nthreads() >= 3 || error("run with -t 3 or more")

@trait X
@trait Y
struct S end
struct T end
@implement Y T
g(::Any) = :Any
g(::X) = :X
h(::X) = :hX
struct HX; v::X; end
mutable struct MX; v::X; MX() = new(); end
macro newHX(x) esc(Expr(:new, :HX, x)) end

q_sub() = S <: X
q_isa(x) = x isa X
q_tassert(x) = try (x::X; true) catch; :TypeError end
q_new(x) = try (@newHX(x); true) catch; :TypeError end
q_stf(x) = try (m = MX(); setfield!(m, :v, x); true) catch; :TypeError end
q_disp(x) = g(x)
q_app(x) = applicable(h, x)
Base.@nospecializeinfer o_disp(@nospecialize(x::Y)) = g(x)
Base.@nospecializeinfer o_isa(@nospecialize(x::Y)) = x isa X

f_sub() = ccall(:jl_subtype, Cint, (Any, Any), S, X) != 0
f_isa(x) = ccall(:jl_isa, Cint, (Any, Any), x, X) != 0
f_tassert(x) = f_isa(x) ? true : :TypeError
f_disp(x) = f_isa(x) ? :X : :Any
f_app(x) = f_isa(x)

const QS = [(:sub, q_sub, f_sub, nothing), (:isa, q_isa, f_isa, S()), (:tassert, q_tassert, f_tassert, S()),
            (:new, q_new, f_tassert, S()), (:stf, q_stf, f_tassert, S()), (:disp, q_disp, f_disp, S()),
            (:app, q_app, f_app, S()), (:o_disp, o_disp, f_disp, T()), (:o_isa, o_isa, f_isa, T())]

const stop = Threads.Atomic{Bool}(false)
const checks = Threads.Atomic{Int}(0)
const wrong = Threads.Atomic{Int}(0)
const firstwrong = Ref{Any}(nothing)
const byq = Dict{Symbol,Int}()
const lk = ReentrantLock()

function reader()
    while !stop[]
        for (name, q, f, v) in QS
            w = Base.get_world_counter()
            a = v === nothing ? Base.invoke_in_world(w, q) : Base.invoke_in_world(w, q, v)
            r = v === nothing ? Base.invoke_in_world(w, f) : Base.invoke_in_world(w, f, v)
            Threads.atomic_add!(checks, 1)
            if a != r
                Threads.atomic_add!(wrong, 1)
                lock(lk) do
                    firstwrong[] === nothing && (firstwrong[] = (name, a, r, Int(w)))
                    byq[name] = get(byq, name, 0) + 1
                end
            end
        end
    end
end

# after each change the readers ask every question at least once more (each a round of both readers)
function pace()
    c0 = checks[]
    while checks[] < c0 + 2 * length(QS) && !stop[]
        yield()
    end
end
function writer()
    for i in 1:ROUNDS
        Traits.declare_membership(S, X, @__MODULE__); pace()
        Traits.declare_membership(Y, X, @__MODULE__); pace()
        ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), S, X, @__MODULE__); pace()
        ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), Y, X, @__MODULE__); pace()
    end
    stop[] = true
end

t0 = time()
r1 = Threads.@spawn reader()
r2 = Threads.@spawn reader()
wt = Threads.@spawn writer()
wait(wt); wait(r1); wait(r2)
println("set_folds_threads: Julia ", VERSION, " ", Base.GIT_VERSION_INFO.commit_short, ", ", Threads.nthreads(), " threads, ",
        ROUNDS, " rounds (4 changes each), ", checks[], " checks, ", wrong[], " wrong",
        firstwrong[] === nothing ? "" : ", first: $(firstwrong[]), by question: $(sort(collect(byq)))", ", ",
        round(time() - t0; digits = 1), " s")
