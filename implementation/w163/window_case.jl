# W-163: a call to a method at a set with a `Type{…}` argument, through invokelatest; the hook prints
# where the runtime calls it from (its first three calls). With window_gc.patch applied and W163_GC_IN_WINDOW=1,
# the runtime collects inside the window of the fault. Run from TraitWorld/.
using TraitWorld
const ORIG = TraitWorld._member_hook
const SEEN = Ref(0)
function bt_hook(@nospecialize(T), @nospecialize(X))
    SEEN[] += 1
    if SEEN[] <= 3
        println("---- hook for $T, $X")
        for fr in stacktrace(backtrace(), true)[1:min(end, 14)]
            println("  ", fr.func, " ", fr.file, ":", fr.line)
        end
    end
    ORIG(T, X)
end
ccall(:jl_set_member_hook, Cvoid, (Any,), bt_hook)
module M
using TraitWorld
@trait_module
export Shape, area, tagged
@trait Shape begin
    area(s::Shape)::Float64
end
tagged(::Type{T}, s::Shape) where {T} = (T, area(s))
end
using .M
struct Sq1; a::Float64; end
M.area(s::Sq1) = s.a^2
@implement Shape Sq1
struct U1 end
println(Base.invokelatest(tagged, U1, Sq1(2.0)))
