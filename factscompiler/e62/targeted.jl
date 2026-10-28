# E-62 (W-9): targeted checks of the inliner changes and of the edges between owners (compiler §2.7, §2.8,
# §6.1, §6.2), in the product setting, without TraitWorld.
#     julia --startup-file=no targeted.jl
const CC = Base.Compiler
npass = Ref(0); nfail = Ref(0)
check(name, ok) = (ok ? (npass[] += 1; println("PASS  ", name)) : (nfail[] += 1; println("FAIL  ", name)); ok)
cis_of(mi) = (out = Core.CodeInstance[]; ci = isdefined(mi, :cache) ? mi.cache : nothing;
              while ci isa Core.CodeInstance; push!(out, ci); ci = isdefined(ci, :next) ? ci.next : nothing; end; out)
invokes(src) = [st.args[1] for st in src.code if st isa Expr && st.head === :invoke]
callee_mi(x) = x isa Core.CodeInstance ? CC.get_ci_mi(x) : x

# §6.1: an invoke at a dispatch tuple names the exact specialization, not the varargs-widened one
module V61
f(xs::Int...) = (s = 0; for x in xs; s += x; end; s)
@noinline g(a, b, c, d, e, h) = f(a, b, c, d, e, h)
end
V61.g(1, 2, 3, 4, 5, 6)
src = only(code_typed(V61.g, NTuple{6,Int}))[1]
ivs = invokes(src)
check("§6.1 the invoke names the exact specialization (no widened Vararg)",
      !isempty(ivs) && all(x -> !(Base.unwrap_unionall(callee_mi(x).specTypes).parameters[end] isa Core.TypeofVararg), ivs) ||
      isempty(ivs))           # inlined entirely is fine too
check("§6.1 no allocation through the call", (V61.g(1, 2, 3, 4, 5, 6); @allocated V61.g(1, 2, 3, 4, 5, 6)) == 0)

# §6.2: an inference cycle through a wrapper keeps one call per turn
module V62
a(n::Int) = n <= 0 ? 0 : wrap(n - 1) + 1
@inline wrap(n::Int) = b(n)
b(n::Int) = a(n)
end
V62.a(10)
srca = only(code_typed(V62.a, (Int,)))[1]
names = [callee_mi(x).def.name for x in invokes(srca)]
check("§6.2 a recursion through wrappers keeps one call per turn ($(names))", length(names) <= 1)

# §2.7 and §2.8: code of the facts owner calling a method that is plain whoever calls it holds an edge to that
# method's plain CodeInstance; replacing the method invalidates the facts caller
module PlainLib
@noinline plainf(x::Int) = x + 1
end
ccall(:jl_set_module_facts, Cvoid, (Any, Cint), PlainLib, 2)       # "never by facts": plain whoever calls (as the compiler)
Core.eval(PlainLib, :(@noinline plainf(x::Int) = x + 1))           # redefined so that the method carries the module's flag
module FactsUser
Base.Experimental.@compiler_options facts=true
usef(x::Int) = Main.PlainLib.plainf(x) * 2
end
check("§2.7 facts code calling plain code: the result", FactsUser.usef(1) == 4)
mi_u = Base.specialize_method(only(methods(FactsUser.usef)), Tuple{typeof(FactsUser.usef),Int}, Core.svec())
fci = [ci for ci in cis_of(mi_u) if ci.owner === :facts && ci.max_world == typemax(UInt)]
plain_edge = !isempty(fci) && any(e -> e isa Core.CodeInstance && e.owner === nothing && CC.get_ci_mi(e).def.name === :plainf, only(fci).edges)
check("§2.7 the facts CodeInstance's edge names plainf's plain CodeInstance", plain_edge)
Core.eval(PlainLib, :(@noinline plainf(x::Int) = x + 10))
check("§2.8 replacing the plain method invalidates the facts caller", !isempty(fci) && only(fci).max_world != typemax(UInt))
check("§2.8 the caller computes the new result", FactsUser.usef(1) == 22)
println(npass[], " pass, ", nfail[], " fail")
