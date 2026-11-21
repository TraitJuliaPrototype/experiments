# W-158, piece 3: where the check of a Callable's signature A runs, on julia-next with the library: a plain function
# passed as itself at an argument declared @nospecialize, a box, a wrapper, the forwarder, a field. Run from the
# library's tree: $JN --project=. <this file>
using TraitWorld
g1(x::Int) = x + 1
g1(x::String) = 0
r(f) = try f() catch e; "raises " * string(nameof(typeof(e))) end
callit(@nospecialize(f::Callable{Tuple{Int}, Int}), x) = f(x)
callplain(f::Callable{Tuple{Int}, Int}, x) = f(x)
println("nospecialize, plain g1, Int: ", r(() -> callit(g1, 1)))
println("nospecialize, plain g1, String: ", r(() -> callit(g1, "s")))
println("nospecialize, the box, String: ", r(() -> callit(Dynamic{Callable{Tuple{Int}, Int}}(g1), "s")))
println("nospecialize, the wrapper, String: ", r(() -> callit(compiled_for(g1), "s")))
println("erased by default (forwarder), String: ", r(() -> callplain(g1, "s")))
println("the box called directly, String: ", r(() -> Dynamic{Callable{Tuple{Int}, Int}}(g1)("s")))
println("which(callit) at g1: ", which(callit, (typeof(g1), String)).sig)
# a value known as Callable through a field, no box: a struct parameter bounded by Callable
struct Holder{F <: Callable{Tuple{Int}, Int}}; f::F; end
println("field typed by a family bounded by Callable: ", r(() -> (h = Holder(g1); h.f("s"))))
struct AHolder; f::Callable{Tuple{Int}, Int}; end
callfield(h::AHolder, x) = h.f(x)
println("field typed Callable{Tuple{Int},Int} holding g1 (stored as?): ", typeof(AHolder(g1).f), " ", r(() -> callfield(AHolder(g1), "s")))
wrapcall() = callit(g1, "s")
println("compiled caller that knows g1: ", r(wrapcall))
wrapcall2(x) = callit(g1, x)
println("compiled caller that knows g1, x::Any at run time: ", r(() -> wrapcall2(Base.inferencebarrier("s"))))
nsi(@nospecialize(f::Callable{Tuple{Int}, Int}), x) = (Base.@noinline; f(x))
Base.@nospecializeinfer nsi2(@nospecialize(f::Callable{Tuple{Int}, Int}), x) = f(x)
w3() = nsi2(g1, "s")
println("@nospecializeinfer, compiled caller: ", r(w3))
