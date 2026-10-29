# U8 (E-254): the REPL case under "never fold a negative" (exploration §13.4, §13.6), in TraitWorld as it
# is (the membership registry is `conforms`). Top-level statements run as at the prompt: each in the
# newest world.
#
#   1. A trait `Shape` (in a trait module `Lib`), a Main type `S` with the operation but no implementation,
#      and a Main function `isx(x) = conforms(typeof(x), Shape)`, compiled at `S` and called: false.
#   2. `@implement Shape S` at the prompt (invalidations logged).
#   3. `isx(S())` again: does it answer true, and was a CodeInstance of `isx` at `S` compiled anew?
#   4. The same call in the world before the `@implement` (`Base.invoke_in_world`), and from a task
#      created before the `@implement`: do they answer false?
#   Part B (end of file): the same three questions for a registry with a min_world per entry, in plain Julia.
#
# Run (product setting):  jl --name w83u8 julia-1.13/julia --project=experiments/w83/u8 experiments/w83/u8/u8.jl
# Run (test bed `all`):   jl --name w83u8all julia-1.13/julia -J julia-1.13/usr/lib/julia/facts/sys.so --project=… u8.jl
using TraitWorld
setting = occursin("facts", unsafe_string(Base.JLOptions().image_file)) ? "all (facts sysimage)" : "product"
println("RESULT U8 setting=$setting julia=$(Base.GIT_VERSION_INFO.commit_short) traitworld=$(pkgversion(TraitWorld))")

@trait_module module Lib
using TraitWorld
export Shape, area
@trait Shape begin
    area(s::Shape)::Float64
end
end
using .Lib
struct S; x::Float64; end
Lib.area(s::S) = s.x

isx(x) = conforms(typeof(x), Shape)

"Every CodeInstance of `f`'s methods at argument types `tt`: (owner, min_world, max_world)."
function cis(f, tt)
    out = Any[]
    for m in methods(f, tt)
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            mi.specTypes <: Tuple{typeof(f), tt.parameters...} || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                push!(out, (owner = ci.owner, min = Int(ci.min_world), max = ci.max_world == typemax(UInt) ? "∞" : Int(ci.max_world)))
                isdefined(ci, :next) || break
                ci = ci.next
            end
        end
    end
    return out
end

const ev = Base.Event()
const early = Threads.@spawn (wait(ev); isx(S(1.0)))     # a task created before the @implement

r1 = isx(S(1.0))
const W0 = Base.get_world_counter()
ci_isx_1 = cis(isx, Tuple{S})
ci_conf_1 = cis(conforms, Tuple{Type, Type})
println("RESULT U8 before: isx(S)=$r1 world=$W0")
println("RESULT U8 before: CodeInstances isx@S=$(ci_isx_1)")
println("RESULT U8 before: CodeInstances conforms=$(length(ci_conf_1)) $(ci_conf_1)")
ct = code_typed(isx, (S,))[1]
println("RESULT U8 code_typed isx@S returns $(ct[2]); body: $(join(string.(ct[1].code), " ; "))")

const LOG = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
@implement Shape S
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
invalidated = [x for x in LOG if x isa Core.MethodInstance]
tags = [x for x in LOG if x isa String]
println("RESULT U8 @implement: world $(W0) -> $(Base.get_world_counter()); invalidated MethodInstances=$(length(invalidated)) tags=$(unique(tags))")
for x in invalidated; println("RESULT U8   invalidated: ", x); end

r2 = isx(S(1.0))
ci_isx_2 = cis(isx, Tuple{S})
ci_conf_2 = cis(conforms, Tuple{Type, Type})
println("RESULT U8 after: isx(S)=$r2")
println("RESULT U8 after: CodeInstances isx@S=$(ci_isx_2)  new=$(length(ci_isx_2) - length(ci_isx_1))")
println("RESULT U8 after: CodeInstances conforms=$(length(ci_conf_2)) $(ci_conf_2)")
r_old = Base.invoke_in_world(W0, isx, S(1.0))
println("RESULT U8 old world (invoke_in_world $W0): isx(S)=$r_old")
notify(ev)
println("RESULT U8 task created before @implement: isx(S)=$(fetch(early))")
println("RESULT U8 conforms(S, Shape) now=$(conforms(S, Shape)); in old world=$(Base.invoke_in_world(W0, conforms, S, Shape))")

# --- Part B: the registry of §13.4 item 1 in plain Julia (no TraitWorld): entries with a min_world,
# read without an edge in the caller's world. Does it give "true, no new CodeInstance" and
# "false in the old world"? (What P1's registry would do; the bar U8 sets.)
abstract type SetB end
struct SB; x::Int; end
const REG = Tuple{Any,Any,UInt}[]                     # (type, set, min_world)
@noinline function member(@nospecialize(T), @nospecialize(X))
    w = Base.tls_world_age()
    for (t, x, mw) in REG
        t === T && x === X && mw <= w && return true
    end
    return false
end
_bump() = nothing
"Declare `T ∈ X`: visible from the next world on, which the redefinition of `_bump` opens (as a method definition does)."
declare!(T, X) = (push!(REG, (T, X, Base.get_world_counter() + 1)); Core.eval(Main, :(_bump() = nothing)); nothing)
isb(x) = member(typeof(x), SetB)
const evB = Base.Event()
const earlyB = Threads.@spawn (wait(evB); isb(SB(1)))
b1 = isb(SB(1))
const WB = Base.get_world_counter()
cb1 = cis(isb, Tuple{SB})
println("RESULT U8B before: isb(SB)=$b1 world=$WB CodeInstances=$cb1")
declare!(SB, SetB)
b2 = isb(SB(1))
cb2 = cis(isb, Tuple{SB})
println("RESULT U8B after: isb(SB)=$b2 world=$(Base.get_world_counter()) CodeInstances=$cb2 new=$(length(cb2) - length(cb1))")
println("RESULT U8B old world (invoke_in_world $WB): isb(SB)=$(Base.invoke_in_world(WB, isb, SB(1)))")
notify(evB)
println("RESULT U8B task created before the declaration: isb(SB)=$(fetch(earlyB))")
