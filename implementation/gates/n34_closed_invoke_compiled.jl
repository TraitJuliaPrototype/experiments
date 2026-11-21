# Gate (W-158, third part; compiler §2.4, §7.6, "An invoke that names its method instance is compiled as any target"):
# a trimmed build's verifier takes an invoke as resolved only where the program can run it. Codegen calls the code
# instance an invoke names as itself; one the build did not compile becomes a call through `jl_invoke` at the policy
# of the code it names, which runs the instance's compiled code of the policy that call asks (`mi_policy_facts_at`).
# Where the build compiles only code of the other policy, the program stops with `MissingCodeError` (the plot's
# program on 61277571fa: `ijl_invoke_facts` from `save`, verifier-clean). The verifier took any code of the instance.
# The case is made by hand: a caller's code that invokes `f34`'s code, and beside it in the build's list another code
# instance of `f34`, of the same policy (resolved) or of the other (refused). On 8b35e4b77c the last is accepted.
#     julia n34_closed_invoke_compiled.jl
const CC = Base.Compiler
const V = CC.TrimVerifier
@noinline f34(x::Int) = x + 1
g34(x::Int) = 2 * f34(x)
@assert g34(1) == 4
w = Base.get_world_counter()
# the caller's optimized code and the code instance its invoke names
interp = CC.NativeInterpreter(w)
mi_g = CC.specialize_method(only(Base._methods_by_ftype(Tuple{typeof(g34), Int}, 1, w)))
ci_g = CC.typeinf_ext(interp, mi_g, CC.SOURCE_MODE_GET_SOURCE)
src_g = interp.codegen[ci_g]
inv = only(st for st in src_g.code if Meta.isexpr(st, :invoke))
ci_f = inv.args[1]
@assert ci_f isa Core.CodeInstance && ci_f.owner === nothing
mi_f = ci_f.def
src_f = something(get(interp.codegen, ci_f, nothing), CC.typeinf_ext(interp, mi_f, CC.SOURCE_MODE_GET_SOURCE) |> c -> interp.codegen[c])
# another code instance of `f34`, compiled by the build, of the policy given
function other(facts::Bool)
    c = Core.CodeInstance(mi_f, nothing, ci_f.rettype, ci_f.exctype, nothing, nothing, Int32(0), ci_f.min_world,
                          ci_f.max_world, UInt32(0), nothing, nothing, Core.svec())
    fl = getfield(c, :flags, :monotonic)
    setfield!(c, :flags, facts ? (fl | 0x20) : (fl & ~0x20), :monotonic)
    return c
end
refused(list) = [e for (warn, e) in first(V.get_verify_typeinf_trim(list, nothing, w)) if !warn && e isa V.CallMissing]
asked_facts = CC.mi_policy_facts_at(mi_f, CC.ci_policy_facts(ci_f))
# (1) the code it names compiled: resolved
@assert isempty(refused(Any[ci_g, src_g, ci_f, src_f]))
# (2) other code of the policy the call asks: resolved (the call through `jl_invoke` runs it)
@assert isempty(refused(Any[ci_g, src_g, other(asked_facts), src_f]))
# (3) other code of the other policy only: refused
r = refused(Any[ci_g, src_g, other(!asked_facts), src_f])
@assert length(r) == 1 && occursin("policy", r[1].desc) "the invoke of code of no compiled policy: $(map(e -> e.desc, r))"
# (4) no code of the instance: refused, as before
@assert length(refused(Any[ci_g, src_g])) == 1
println("n34_closed_invoke_compiled: OK")
