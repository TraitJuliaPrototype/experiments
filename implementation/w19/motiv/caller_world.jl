# W-19, P16: the calling convention `:caller_world`. A pointer made in one world; a method defined
# later; a call through the pointer from the old world runs the old method, from the new world the
# new one. A plain `@cfunction` pointer runs the latest world in both.
#   julia --startup-file=no caller_world.jl
using Test
g(x::Int) = 1
call_g(x) = g(x)
mkptr(cc) = @eval $(Expr(:cfunction, Ptr{Cvoid}, QuoteNode(call_g), Int, :(Core.svec(Int)), QuoteNode(cc)))
p_world = mkptr(:caller_world)
p_plain = mkptr(:ccall)
callp(p, x) = ccall(p, Int, (Int,), x)
w_old = Base.get_world_counter()
@test callp(p_world, 1) == 1
@eval g(x::Int) = 2          # a later definition
@test Base.invoke_in_world(w_old, callp, p_world, 1) == 1   # the old world: the old method
@test callp(p_world, 1) == 2                                 # the latest world: the new one
@test Base.invoke_in_world(w_old, callp, p_plain, 1) == 2   # a plain cfunction: the latest world
@eval g(x::Int) = 3
@test callp(p_world, 1) == 3
@test Base.invoke_in_world(w_old, callp, p_world, 1) == 1
println("caller_world: all tests passed")
