# Gate for the facts series' F9 (ownership; declares no trait): a call of an owner-only function is a fact
# at any signature, so the facts inference infers it, with its edge, where a call of any other function at
# that signature is a run-time site. Owner-only: a function its owner declared so (`jl_set_owner_only`),
# or a function of a module with `@compiler_options owner_only=true` that the module neither exports nor
# declares `public` (a submodule takes the option). Plain inference is unchanged.
#     julia --startup-file=no g-f9_owner_only.jl
const CC = Core.Compiler
# an interpreter of the current world at each query (one made earlier does not see later definitions)
const facts = true; const plain = false
rt(f, T, mode::Bool) = Base.code_typed(f, T; interp = CC.NativeInterpreter(; facts = mode))[1][2]
fx(f, T) = Base.infer_effects(f, T; interp = CC.NativeInterpreter(; facts = true))

module Own
Base.Experimental.@compiler_options owner_only=true
export pub_exported
public pub_declared
helper(x::Int) = 1
helper(x::Float64) = 2.0
pub_exported(x::Int) = 1
pub_exported(x::Float64) = 2.0
pub_declared(x::Int) = 1
pub_declared(x::Float64) = 2.0
call_helper(x::Real) = helper(x)
call_exported(x::Real) = pub_exported(x)
call_declared(x::Real) = pub_declared(x)
call_kw(x::Real) = kwhelper(x; k = 1)
kwhelper(x::Int; k) = k
kwhelper(x::Float64; k) = 2.0
module Sub
inner(x::Int) = 1
inner(x::Float64) = 2.0
call_inner(x::Real) = inner(x)
end
end

module Open
other(x::Int) = 1
other(x::Float64) = 2.0
call_other(x::Real) = other(x)
declared(x::Int) = 1
declared(x::Float64) = 2.0
call_declared(x::Real) = declared(x)
end

@assert ccall(:jl_get_module_options, Cint, (Any,), Own) == 64
@assert ccall(:jl_get_module_options, Cint, (Any,), Own.Sub) == 64   # inherited at creation
@assert ccall(:jl_get_module_options, Cint, (Any,), Open) == 0
@assert CC.is_owner_only(typeof(Own.helper)) && CC.is_owner_only(typeof(Own.Sub.inner))
@assert !CC.is_owner_only(typeof(Own.pub_exported)) && !CC.is_owner_only(typeof(Own.pub_declared))
@assert !CC.is_owner_only(typeof(Open.other))

# owner-only by the module's option: a fact at `Real`, inferred; plain inference the same
@assert rt(Own.call_helper, (Real,), facts) === Union{Int, Float64}
@assert rt(Own.call_helper, (Real,), plain) === Union{Int, Float64}
@assert CC.is_nortsite(fx(Own.call_helper, (Real,)))
@assert rt(Own.Sub.call_inner, (Real,), facts) === Union{Int, Float64}
@assert rt(Own.call_kw, (Real,), facts) === Union{Int, Float64}
# exported, or declared public: not owner-only, a run-time site at `Real`
@assert rt(Own.call_exported, (Real,), facts) === Any
@assert rt(Own.call_declared, (Real,), facts) === Any
@assert !CC.is_nortsite(fx(Own.call_exported, (Real,)))
# a module without the option: a run-time site; a function its owner declares owner-only (before any
# caller is inferred: the declaration ends no code), a fact
@assert rt(Open.call_other, (Real,), facts) === Any
@assert !CC.is_owner_only(typeof(Open.declared))
ccall(:jl_set_owner_only, Cvoid, (Any, Any), Open, :declared)
@assert ccall(:jl_binding_owner_only_p, Cint, (Any, Any), Open, :declared) == 1
@assert CC.is_owner_only(typeof(Open.declared))
@assert rt(Open.call_declared, (Real,), facts) === Union{Int, Float64}
@assert rt(Open.call_other, (Real,), facts) === Any
# an unknown option bit is refused
@assert try ccall(:jl_set_module_option, Cvoid, (Any, Cint, Cint), Open, 3, 1); false catch; true end
println("g-f9_owner_only: OK")
