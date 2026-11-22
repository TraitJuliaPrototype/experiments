# W-158, sixth part: the rule's checks taken out of the session's compiler (a mutant), so that the gate
# `gates/n35_trusted_result.jl` can be seen to fail without them on the build that has them: no check after a call
# whose code may be another instance than the one inferred, and `typeassert`'s check where a `Callable`'s result is
# checked (the direct call, a closed build's split). The trusted effect and the widening of a marked call's result
# stay. `julia --project=<TraitWorld> -e 'include("m-probes/mutant.jl"); include("<gate>")'`
const CC = Base.Compiler
Core.eval(CC, :(check_trusted_result!(todo::Vector{Pair{Int,Any}}, ntodo::Int, ir::IRCode, idx::Int,
    sig::Union{Nothing,Signature}, trusted::UInt32, state::InliningState) = nothing))
Core.eval(CC, :(trusted_result_check(@nospecialize(val), @nospecialize(T), trusted::UInt32, world::UInt) =
    Expr(:call, GlobalRef(Core, :typeassert), val, T)))
CC.activate_codegen!()
println(stderr, "mutant: the rule's checks taken out of the session's compiler")
