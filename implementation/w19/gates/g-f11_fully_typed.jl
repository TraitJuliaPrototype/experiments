# Gate for the facts series' F11 (declares no trait): fully typed mode. A module's option
# (`@compiler_options fully_typed=warn|enforce`) or a method's meta (`:fully_typed_warn`,
# `:fully_typed_enforce`) compiles the method by facts; code at a signature that holds a run-time site
# starts with a call of `jl_not_fully_typed(site)`: without a hook, enforce raises and warn does nothing;
# with a hook (`jl_set_fully_typed_hook`), the hook gets the site, once per site under warn, at every run
# under enforce. Fully typed code has no check. A module without the option is unchanged.
#     julia --startup-file=no g-f11_fully_typed.jl
const FACTS = 0x20
policy(f, T) = (mi = Base.method_instance(f, T); ci = mi.cache; (ci.flags & FACTS) != 0 ? :facts : :plain)

module Enf
Base.Experimental.@compiler_options fully_typed=enforce
typed(x::Int) = x + 1
untyped(v::Vector{Any}) = v[1] + 1
end
module Warn
Base.Experimental.@compiler_options fully_typed=warn
untyped(v::Vector{Any}) = v[1] + 1
end
module Off
untyped(v::Vector{Any}) = v[1] + 1
end
@eval Off bymeta(v::Vector{Any}) = $(Expr(:block, Expr(:meta, :fully_typed_enforce), :(v[1] + 1)))

@assert ccall(:jl_get_module_options, Cint, (Any,), Enf) == 32
@assert ccall(:jl_get_module_options, Cint, (Any,), Warn) == 16
@assert ccall(:jl_method_fully_typed, Cint, (Any,), which(Enf.typed, (Int,))) == 2
@assert ccall(:jl_method_fully_typed, Cint, (Any,), which(Warn.untyped, (Vector{Any},))) == 1
@assert ccall(:jl_method_fully_typed, Cint, (Any,), which(Off.untyped, (Vector{Any},))) == 0
@assert ccall(:jl_method_fully_typed, Cint, (Any,), which(Off.bymeta, (Vector{Any},))) == 2
@assert ccall(:jl_method_policy, Cint, (Any,), which(Enf.typed, (Int,))) == 1   # facts

# no hook: fully typed code runs; code with a run-time site raises under enforce, runs under warn
@assert Enf.typed(1) == 2 && policy(Enf.typed, (Int,)) === :facts
@assert try Enf.untyped(Any[1]); false catch e; occursin("not fully typed", sprint(showerror, e)) end
@assert Warn.untyped(Any[1]) == 2
@assert Off.untyped(Any[1]) == 2 && policy(Off.untyped, (Vector{Any},)) === :plain
@assert try Off.bymeta(Any[1]); false catch e; occursin("not fully typed", sprint(showerror, e)) end

# a hook: it gets the site (the instance, the level, warned, the kind); under warn once per site
seen = Any[]
hook(site) = (push!(seen, site); site[2] == 2 && error("hook: not fully typed"); nothing)
ccall(:jl_set_fully_typed_hook, Cvoid, (Any,), hook)
@eval Warn untyped2(v::Vector{Any}) = v[1] * 2
@assert Warn.untyped2(Any[3]) == 6 && Warn.untyped2(Any[4]) == 8
@assert length(seen) == 1 && seen[1][1] === Base.method_instance(Warn.untyped2, (Vector{Any},)) && seen[1][2] == 1 && seen[1][4] == 1
@assert try Enf.untyped(Any[1]); false catch e; occursin("hook: not fully typed", sprint(showerror, e)) end
@assert try Enf.untyped(Any[1]); false catch e; true end
@assert length(seen) == 3
@assert Enf.typed(5) == 6 && length(seen) == 3
ccall(:jl_set_fully_typed_hook, Cvoid, (Any,), nothing)
println("g-f11_fully_typed: OK")
