# W-163: the deterministic probe. The member hook (the library's check at first use) runs a full
# collection before it checks. A call to a method at a set whose argument tuple type is not
# interned (a `Type{…}` argument makes it abstract, so Julia's type cache does not hold it) then
# reaches the method lookup after the collection. If the runtime holds that tuple type unrooted
# across the hook, the lookup reads freed memory.
# Run from TraitWorld/:  ../<tree>/julia --project=. --startup-file=no ../experiments/implementation/w163/gc_in_hook.jl
# With W163_STRESS=N and a runtime built with WITH_GC_DEBUG_ENV=1: a collection at every N-th allocation
# of the C runtime from the probe's call to the hook (dispatch's method lookup before the hook: the
# window of the fault; jl_gc_debug_env's `other` counter, gc-debug.c), each with
# the collector's verification and its scrub, which overwrites (0xff) an unmarked object the C stack
# still points to: a use of a freed object then faults at once.
using TraitWorld

const STRESS = parse(Int, get(ENV, "W163_STRESS", "0"))
# jl_gc_debug_env_t: int wait_for_debugger; jl_alloc_num_t pool, other, print; each jl_alloc_num_t is
# {num, next, min, interv, max}::UInt64 and unsigned short random[3] (48 bytes)
function stress!(on::Bool)
    STRESS == 0 && return
    other = Ptr{UInt64}(cglobal(:jl_gc_debug_env)) + 8 + 48
    num = unsafe_load(other, 1)
    unsafe_store!(other, on ? num + 1 : typemax(UInt64), 2)   # next
    unsafe_store!(other, on ? UInt64(STRESS) : UInt64(0), 4)  # interv
    unsafe_store!(other, typemax(UInt64), 5)                  # max
    nothing
end

const ORIG = TraitWorld._member_hook
const NGC = Ref(0)
const KEEP = Ref{Any}(nothing)
# After the collection, fresh type objects of a DataType's size take the cells it freed: a tuple type
# that was freed is then another, valid type, and the lookup that reads it answers for that type.
function gc_hook(@nospecialize(T), @nospecialize(X))
    stress!(false)  # the window is the runtime's, before the hook: the hook and the compilation after it run unstressed
    NGC[] += 1
    GC.gc(true)
    STRESS == 0 && (KEEP[] = Any[Tuple{Type{Val{(NGC[], i)}}} for i in 1:2000])  # the scrub does this under stress
    ORIG(T, X)
end
ccall(:jl_set_member_hook, Cvoid, (Any,), gc_hook)

module M
using TraitWorld
@trait_module
export Shape, area, tagged, tagged2, tagged3
@trait Shape begin
    area(s::Shape)::Float64
end
# methods at a set, with a Type argument in front and behind
tagged(::Type{T}, s::Shape) where {T} = (T, area(s))
tagged2(s::Shape, ::Type{T}) where {T} = (T, area(s))
tagged3(::Type{T}, s::Shape, x) where {T} = (T, area(s), x)
end
using .M

ok = true
for k in 1:20
    # a fresh type each round: a fresh struct, a fresh membership, a first use, a fresh tuple type
    S = Symbol(:Sq, k)
    Core.eval(Main, :(struct $S; a::Float64; end))
    Core.eval(Main, :(M.area(s::$S) = s.a^2))
    Core.eval(Main, :(@implement Shape $S))
    s = Core.eval(Main, :($S(2.0)))
    # a fresh Type{} parameter each round too, so that the tuple type is new
    U = Core.eval(Main, :(struct $(Symbol(:U, k)) end; $(Symbol(:U, k))))
    for (f, args, want) in ((tagged, (U, s), (U, 4.0)), (tagged2, (s, U), (U, 4.0)), (tagged3, (U, s, k), (U, 4.0, k)))
        r = try
            stress!(true)
            try
                Base.invokelatest(f, args...)
            finally
                stress!(false)
            end
        catch e
            sprint(showerror, e)
        end
        r == want || (println("round $k, $(nameof(f)): got ", first(string(r), 300)); global ok = false)
    end
end
println("hook ran $(NGC[]) times; stress every $(STRESS) allocations; results ", ok ? "right" : "WRONG")
println(ok && NGC[] > 0 ? "GC_IN_HOOK PASS" : "GC_IN_HOOK FAIL")
