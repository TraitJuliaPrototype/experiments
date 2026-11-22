# W-143e (E-541; open issue 219): a call whose inferred instance is narrower than the instance it runs. Inference infers
# `h(@nospecialize(a))` at the argument's type; the inliner, which does not inline it, calls the compileable instance
# `h(::Any)` (`compileable_specialization`) and names it in the caller's record. No inference has made that instance's
# code when the caller finishes: the compile queue infers it after. So the caller's edge names a MethodInstance alone
# (compiler §3.2), whatever code it gets later. With `Base.@nospecializeinfer` inference infers the instance that runs,
# and the edge names its code. Plain Julia (vanilla v1.13.2) records the same edge.
#     julia --startup-file=no motiv/widened.jl
# four callees, so that no probe compiles another's callee first; the bodies call builtins only, so the instance
# at `Any` is in the deep class where the bit exists, and the caller is where its edge names that code
@noinline h1(@nospecialize(a)) = a === Any ? a : Nothing <: a ? Nothing : a
@noinline h2(@nospecialize(a)) = a === Any ? a : Nothing <: a ? Nothing : a
Base.@nospecializeinfer @noinline g1(@nospecialize(a)) = a === Any ? a : Nothing <: a ? Nothing : a
Base.@nospecializeinfer @noinline g2(@nospecialize(a)) = a === Any ? a : Nothing <: a ? Nothing : a
kh(a::Type) = invoke(h1, Tuple{Any}, a)
kg(a::Type) = invoke(g1, Tuple{Any}, a)
ch(a::Type) = h2(a)       # an ordinary call: the same
cg(a::Type) = g2(a)
cis(f) = [c for m in methods(f) for mi in Base.specializations(m) if isdefined(mi, :cache)
          for c in (let c = mi.cache, v = Core.CodeInstance[c]; while isdefined(c, :next); c = c.next; push!(v, c); end; v end)
          if c.owner === nothing && c.max_world == typemax(UInt)]
show_edge(e) = e isa Core.CodeInstance ? "code of $(e.def.specTypes.parameters[2:end])" :
               e isa Core.MethodInstance ? "INSTANCE $(e.specTypes.parameters[2:end]) alone" : e isa Type ? nothing : string(e)
inst(f) = sort([string(mi.specTypes.parameters[2:end]) for m in methods(f) for mi in Base.specializations(m)])
println("julia ", Base.GIT_VERSION_INFO.commit_short)
for (k, f) in (("invoke, no @nospecializeinfer", kh), ("invoke, @nospecializeinfer", kg), ("call, no @nospecializeinfer", ch), ("call, @nospecializeinfer", cg))
    f(Union{Int, Nothing})
    ci = only(cis(f))
    es = filter(!isnothing, [show_edge(e) for e in ci.edges])
    G2 = isdefined(Base.Compiler, :edges_satisfy_g2) ? string(" | the G2 bit ", (ci.flags & 0x10) != 0) : ""
    println(rpad(k, 32), "edges: ", join(es, ", "), G2)
end
println("instances: h1 ", inst(h1), ", h2 ", inst(h2), " | g1 ", inst(g1), ", g2 ", inst(g2))
