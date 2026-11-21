# W-158, second part: why a type is a member at a set type in the build's check run in the session: the
# places it was forgotten at, and the flows that bring each to the set type. Include after flow.jl's
# definitions (PATCH=1): flowdebug(f, args, T, X).
function flowdebug(f, args, @nospecialize(T), @nospecialize(X))
    world = Base.get_world_counter()
    mi = CC.specialize_method(Base._methods_by_ftype(Base.signature_type(f, args), 1, world)[1])
    owner = CC.ClosedCheck(TraitWorld._build_base())
    mq = ccall(:jl_set_membership_query_world, UInt, (UInt,), world)
    try
        empty!(CC.CLOSED_OPERATION_INSTANCES); CC.closed_used_reset!()
        rounds = 0
        while true
            empty!(CC.CLOSED_CANDIDATE_COUNTS)
            codeinfos = []
            interp = CC.NativeInterpreter(world; inf_params = CC.InferenceParams(; force_enable_inference = true), closed = owner)
            CC.compile!(codeinfos, CC.CompilationQueue(; interp = interp, ) |> q -> (append!(q, Any[mi]); q); invokelatest_queue = CC.CompilationQueue(; interp), external_linkage = false)
            CC.closed_note_used!(codeinfos)
            println("round ", rounds + 1, ": ", length(codeinfos) ÷ 2, " instances; splits ",
                    [X => (n, CC.closed_candidates(X)) for (X, n) in CC.CLOSED_CANDIDATE_COUNTS])
            (rounds < 16 && CC.closed_candidates_grew()) || CC.closed_no_member_round(rounds) || break
            rounds += 1
            stale = Base.IdSet{Any}()
            CC.closed_build_reinfer!(world, stale, owner)
            CC.closed_invalidate_callers!(codeinfos, stale, world, owner)
        end
        println("forgotten ", T, " at: ", get(CC.CLOSED_USED_AT, T, Any[]))
        R = CC.closed_reaching_places(X)
        println("places reaching ", X, ": ", collect(R))
        for P in R
            println("  ", P, " <- ", collect(get(CC.CLOSED_FLOWS, P, Any[])))
        end
    finally
        CC.closed_used_reset!()
        ccall(:jl_set_membership_query_world, UInt, (UInt,), mq)
    end
end
