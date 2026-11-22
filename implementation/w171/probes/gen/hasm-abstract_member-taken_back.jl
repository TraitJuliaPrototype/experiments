# set_folds probe: abstract_member/taken_back, question hasm, form r, copy 0 (first compiled after change 0), world 1
# compiled "false" against fresh "true" (expected "true")
#     julia --project=experiments/implementation <this file>
using Traits
SFLIB_DECLARE(mem, set) = Traits.declare_membership(mem, set, @__MODULE__)
# the methods of f valid in the task's world, read from the table's definitions (a query that is no leaf type reads no
# dispatch cache), and the one dispatch selects for the argument types `tt` there, by `jl_subtype` and specificity
SF_methods(f) = (ms = Base._methods_by_ftype(Tuple{typeof(f), Vararg{Any}}, -1, Base.tls_world_age());
                 ms === nothing ? Method[] : Method[m.method for m in ms])
function SF_select(f, tt)
    sig = Tuple{typeof(f), tt.parameters...}
    app = [m for m in SF_methods(f) if ccall(:jl_subtype, Cint, (Any, Any), sig, m.sig) != 0]
    isempty(app) && return nothing
    best = [m for m in app if all(o -> o === m || Base.morespecific(m.sig, o.sig), app)]
    return length(best) == 1 ? best[1] : :ambiguous
end
SF_dispatch(f, x) = (m = SF_select(f, Tuple{Core.Typeof(x)}); m isa Method ? Core.invoke(f, Base.tuple_type_tail(m.sig), x) :
                     m === nothing ? :nomethod : m)
SF_hasmethod(f, A) = SF_select(f, Tuple{A}) isa Method
SF_which(f, x) = (m = SF_select(f, Tuple{Core.Typeof(x)}); m isa Method ? m : :nomethod)

@trait X
@trait Yc
@trait Zc
struct Ph{T} end
abstract type AM end
struct SA <: AM end
const A = AM
const B = X
g(::Any) = :Any
g(::B) = :B
h(::B) = :hB
function g end
function h end
struct HB; v::B; end
macro newHB(x) esc(Expr(:new, :HB, x)) end
q() = hasmethod(h, Tuple{A})
r() = q()
fresh() = Main.SF_hasmethod(h, A)
call(f, a...) = try f(a...) catch e; nameof(typeof(e)) end
worlds = [Base.get_world_counter()]
println("compiled in world 0: ", call(r))
SFLIB_DECLARE(AM, X)
push!(worlds, Base.get_world_counter())
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), AM, X, @__MODULE__)
push!(worlds, Base.get_world_counter())
for j in 0:length(worlds)-1
    println("world ", j, ": compiled ", call(Base.invoke_in_world, worlds[j+1], r), ", fresh ", call(Base.invoke_in_world, worlds[j+1], fresh))
end
