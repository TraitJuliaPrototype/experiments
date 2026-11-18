# Open issue 172, compiler C-82 (the performance review of 2026-11-09, H2): written by the review, adopted unchanged.
# Does jl_has_unmet_argument see a membership in Callable (by a call method) at All{AbstractString, Callable}?
struct MyS <: AbstractString end
(s::MyS)(x) = 1
println("MyS <: Callable: ", MyS <: Core.Callable)
f(::AbstractString, xs...) = :str
f(::Core.Callable, ::Int) = :callable
w = Base.get_world_counter()
T = Tuple{typeof(f), Core.Callable, Int}
CC = Base.Compiler
r = CC.findall(T, CC.method_table(CC.NativeInterpreter()); limit = -1)
println("matches at (Callable, Int): ", [m.method.sig for m in r], " ambig=", r.ambig)
isect = Tuple{typeof(f), Core.All{Tuple{AbstractString, Core.Callable}}, Int}
println("unmet(All{AbstractString, Callable}): ", ccall(:jl_has_unmet_argument, Cint, (Any, UInt), isect, w))
g(x::Core.Callable) = f(x, 1)
println("g(MyS()) dynamic dispatch: ", try f(MyS(), 1) catch e; typeof(e) end)
println("g(MyS()) through compiled code typed Callable: ", try g(MyS()) catch e; typeof(e) end)
println(Base.code_typed(g, (Core.Callable,))[1][1].code)
