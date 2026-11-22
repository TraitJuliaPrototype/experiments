# W-171 (E-542): a method that names the member in a variable's lower bound, called at a type that names the set: a
# membership changes the selection (compiler §5.5), and no walk replays the method. Declared: a call compiled before
# the membership keeps its selection; the dispatch cache keeps its entry.
#     julia --project=experiments/implementation lb_dispatch_declared.jl
using Traits
@trait X
struct S end
struct Ph{T} end
g(::Any) = :Any
g(::Ph{T}) where T>:S = :lower_bound
c(x) = g(x)
dyn(x) = g(Base.inferencebarrier(x))
x = Ph{X}()
println("before: compiled ", c(x), "  dynamic ", dyn(x))
@implement X S
println("after the membership: compiled ", c(x), "  dynamic ", dyn(x), "  expected :lower_bound (Ph{X} <: Ph{T} where T>:S: ",
        ccall(:jl_subtype, Cint, (Any, Any), Ph{X}, Ph{T} where T>:S) != 0, ")")
