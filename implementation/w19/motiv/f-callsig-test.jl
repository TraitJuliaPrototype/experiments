# W-19 up/19: the test it adds to test/worlds.jl, standalone (its helper copied), to run on vanilla as the control.
using Test
function method_instance(f, types=Base.default_tt(f))
    m = which(f, types)
    inst = nothing
    tt = Base.signature_type(f, types)
    for mi in Base.specializations(m)
        if mi.specTypes <: tt && tt <: mi.specTypes
            inst = mi
            break
        end
    end
    return inst
end

# a call that reaches an instance wider than its own signature (a `@nospecialize` argument inferred
# so, `!==`) keeps its signature on the backedge: a method defined later invalidates the caller only
# where it meets the call's signature
Base.@nospecializeinfer kcallsig(@nospecialize(x)) = x isa Int ? 1 : 2
ccallsig(x::Int) = kcallsig(x)
dcallsig(@nospecialize(x)) = kcallsig(x)
ecallsig(x::Integer) = kcallsig(x)
@test ccallsig(1) == 1 && dcallsig(1) == 1 && ecallsig(Int8(1)) == 2
let cc = method_instance(ccallsig, (Int,)).cache, cd = method_instance(dcallsig, (Any,)).cache,
    ce = method_instance(ecallsig, (Int8,)).cache
    @test cc.max_world == cd.max_world == ce.max_world == typemax(UInt)
    @eval kcallsig(x::String) = 3
    @test cc.max_world == typemax(UInt)  # a caller at Int: the new method does not meet its call
    @test cd.max_world != typemax(UInt)  # a caller at Any is invalidated
    @test ce.max_world == typemax(UInt)
    @test dcallsig("s") == 3
    @eval kcallsig(x::Int8) = 4
    @test ce.max_world != typemax(UInt)  # a method that meets the call's signature invalidates
    @test ecallsig(Int8(1)) == 4 && ccallsig(1) == 1
end
struct NeCallsig end
necallsig(x::Int, y::Int) = x !== y
@test necallsig(1, 2)
let ci = method_instance(necallsig, (Int, Int)).cache
    @test ci.max_world == typemax(UInt)
    Base.:(!==)(::NeCallsig, ::NeCallsig) = false
    @test ci.max_world == typemax(UInt)  # a method of `!==` for another type leaves a caller at Int
end
