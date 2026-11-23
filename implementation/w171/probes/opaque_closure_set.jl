# W-171, fourth part (E-545; compiler C-170): an opaque closure's call is inferred to throw where its arguments' types
# and the closure's signature do not intersect (`abstract_call_opaque_closure`). Where the signature names a set and the
# argument is a type that could join it, a membership changes that answer after the caller is inferred: the closure
# is created and called in one function (inference sees it as a `PartialOpaque`), compiled before `S` joins `X`, and
# asked again after the membership. The runtime's own call checks the arguments when it runs, so the code compiled
# before must not have folded the call to a throw. The compiled code is run last: code that kept the fold runs into
# `unreachable` once the call returns.
#     julia --project=experiments/implementation opaque_closure_set.jl
using Traits
@trait X
struct S end
f() = (oc = Base.Experimental.@opaque (x::X) -> :called; oc(S()))
r(g) = try g() catch e; Symbol(nameof(typeof(e))) end
ci() = (mi = Base.method_instance(f, ()); c = mi.cache;
        "rettype $(c.rettype), max_world $(c.max_world == typemax(UInt) ? "open" : Int(c.max_world))")
println("before: ", r(f), "; the caller's code: ", ci())
Traits.declare_membership(S, X, @__MODULE__)
fresh() = (oc = Base.Experimental.@opaque (x::X) -> :called; oc(Base.inferencebarrier(S())))
println("after:  fresh ", r(fresh), "; the caller's code: ", ci(), "; inferred afresh ", Base.return_types(f, ()))
println("after:  the caller ", r(f))
