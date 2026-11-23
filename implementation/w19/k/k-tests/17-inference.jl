# the definition-time check's interpreter: Julia's inference with a cache of its own, calling a hook at
# each known call
let calls = Any[]
    defcheck_hook(interp, @nospecialize(f), argtypes, sv) = (push!(interp.state, f); nothing)
    defcheck_f(x) = sin(x) + 1
    m = only(methods(defcheck_f))
    interp = Compiler.DefinitionCheckInterpreter(Base.get_world_counter(), defcheck_hook, calls)
    frame = Base.invoke_in_typeinf_world(Compiler.typeinf_frame, interp, m, Tuple{typeof(defcheck_f), Float64},
                                         Core.svec(), false)
    @test frame isa Compiler.InferenceState
    @test sin in calls && (+) in calls
    @test all(mi -> !isdefined(mi, :cache), Base.specializations(m))   # no code in the session's cache
end
