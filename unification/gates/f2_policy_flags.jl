# Gate (W-100, slice 2a; compiler §2.1, §2.2): the module option `facts` and the trait language's
# scope options, inherited by submodules; the method flag from `Expr(:meta, :facts_boundary)` and
# `Expr(:meta, :facts_always)`; a method's own policy; the flag carried into every method a
# definition makes (keyword sorters, positional forwarders: C-43).
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
# every method a definition makes takes the flag: the body, the keyword sorter, the positional
# method without keywords and its forwarders for the optional arguments
@eval kw(x, y = 1; z = 2) = $(Expr(:block, Expr(:meta, :facts_boundary), :(x + y + z)))
@eval opt(x, y = 1, w = 2) = $(Expr(:block, Expr(:meta, :facts_always), :(x + y + w)))
kwms = [methods(kw)..., methods(Core.kwcall, (NamedTuple, typeof(kw), Vararg))...]
bodyms = [m for f in names(Main; all = true) if startswith(string(f), "#kw#")
            for m in methods(getfield(Main, f))]
@assert length(kwms) >= 3 && length(bodyms) == 1
@assert all(m -> m.facts == 1, kwms) "keyword sorter and positional methods: $([m.facts for m in kwms])"
@assert only(bodyms).facts == 1
@assert length(methods(opt)) == 3 && all(m -> m.facts == 2, methods(opt)) "forwarders: $([m.facts for m in methods(opt)])"
@assert kw(1) == 4 && kw(1, 2; z = 3) == 6 && opt(1) == 4
println("f2_policy_flags: OK")
