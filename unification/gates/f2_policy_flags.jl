# Gate (W-100, slice 2a; compiler §2.1, §2.2): the module option `facts` and the trait language's
# scope options, inherited by submodules; the method flag from `Expr(:meta, :facts_boundary)` and
# `Expr(:meta, :facts_always)`; a method's own policy.
include("util.jl")
module FM
Base.Experimental.@compiler_options facts=true bounded=true first_seen=true
f(x) = x
module Sub
g(x) = x
end
end
mfacts(m::Module) = ccall(:jl_get_module_facts, Cint, (Any,), m)
mopts(m::Module) = ccall(:jl_get_module_trait_options, Cint, (Any,), m)
isfacts(m::Method) = ccall(:jl_method_is_facts, Cint, (Any,), m) != 0
@assert mfacts(FM) == 1 && mfacts(FM.Sub) == 1 && mfacts(Main) == 0
@assert mopts(FM) == 1 | 8 && mopts(FM.Sub) == 1 | 8 && mopts(Main) == 0
@assert isfacts(only(methods(FM.f))) && isfacts(only(methods(FM.Sub.g)))
h(x) = x
@assert !isfacts(only(methods(h))) && only(methods(h)).facts == 0
@eval k(x) = $(Expr(:block, Expr(:meta, :facts_always), :x))
@assert only(methods(k)).facts == 2 && isfacts(only(methods(k)))
@eval b(x) = $(Expr(:block, Expr(:meta, :facts_boundary), :x))
@assert only(methods(b)).facts == 1 && !isfacts(only(methods(b)))
println("f2_policy_flags: OK")
