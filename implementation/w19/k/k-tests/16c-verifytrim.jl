# an invoke whose code the build did not compile is resolved where the build compiles the instance's code of
# the policy the call through `jl_invoke` asks
@noinline vt_f(x::Int) = x + 1
vt_g(x::Int) = 2 * vt_f(x)
@test vt_g(1) == 4
let w = Base.get_world_counter(), interp = Compiler.NativeInterpreter(w)
    mi_g = Compiler.specialize_method(only(Base._methods_by_ftype(Tuple{typeof(vt_g), Int}, 1, w)))
    ci_g = Compiler.typeinf_ext(interp, mi_g, Compiler.SOURCE_MODE_GET_SOURCE)
    src_g = interp.codegen[ci_g]
    ci_f = only(st for st in src_g.code if Meta.isexpr(st, :invoke)).args[1]::Core.CodeInstance
    mi_f = ci_f.def
    src_f = something(get(interp.codegen, ci_f, nothing),
                      interp.codegen[Compiler.typeinf_ext(interp, mi_f, Compiler.SOURCE_MODE_GET_SOURCE)])
    function other(facts::Bool)          # another code instance of `vt_f`, of the policy given
        c = Core.CodeInstance(mi_f, nothing, ci_f.rettype, ci_f.exctype, nothing, nothing, Int32(0), ci_f.min_world,
                              ci_f.max_world, UInt32(0), nothing, nothing, Core.svec())
        fl = getfield(c, :flags, :monotonic)
        setfield!(c, :flags, facts ? (fl | 0x20) : (fl & ~0x20), :monotonic)
        return c
    end
    refused(list) = [e for (warn, e) in first(get_verify_typeinf_trim(list, nothing, w)) if !warn && e isa CallMissing]
    asked = Compiler.mi_policy_facts_at(mi_f, Compiler.ci_policy_facts(ci_f))
    @test isempty(refused(Any[ci_g, src_g, ci_f, src_f]))
    @test isempty(refused(Any[ci_g, src_g, other(asked), src_f]))
    r = refused(Any[ci_g, src_g, other(!asked), src_f])
    @test length(r) == 1 && occursin("policy", r[1].desc)
    @test length(refused(Any[ci_g, src_g])) == 1
end
