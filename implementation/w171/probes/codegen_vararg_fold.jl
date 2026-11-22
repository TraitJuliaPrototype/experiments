# W-171 (E-542): code generation folds `<:` of two known types where `jl_could_join` answers 0; for two tuples of
# different lengths (a Vararg tail) it answered 0, and the answer, computed when the code was compiled, stood after
# the membership (a fresh-looking function behind `inferencebarrier`).
#     julia --project=experiments/implementation codegen_vararg_fold.jl [q]
using Traits
@trait X
struct S end
const A = Tuple{Int, S, S}
const B = Tuple{Int, Vararg{X}}
fresh() = Base.inferencebarrier(A) <: Base.inferencebarrier(B)
sub(a, b) = Base.inferencebarrier(a) <: Base.inferencebarrier(b)
q() = A <: B
println("w0: fresh ", fresh())
ARGS == ["q"] && println("q ", q())
@implement X S
println("w1: fresh ", fresh(), " sub ", sub(A, B), " direct ", Base.inferencebarrier(A) <: B)
for mi in Base.specializations(only(methods(fresh))); c = mi.cache; println(Int(c.min_world), ":", c.max_world, " ", c.rettype, " ", isdefined(c,:rettype_const) ? c.rettype_const : "-", " ", c.edges); end
