# W-158, second part: the build's check's rounds for `f(args...)`, run in the session as `closed_check` runs
# them, each round's splits with their members, and at the end the instances that only raise (result
# `Union{}`). Include after the program's definitions (and `patch_c.jl`): check_rounds(f, args).
function check_rounds(f, args; raising = true, show = nothing, showcode = nothing)
    CC = Base.Compiler
    world = Base.get_world_counter()
    mi = CC.specialize_method(Base._methods_by_ftype(Base.signature_type(f, args), 1, world)[1])
    owner = CC.ClosedCheck(TraitWorld._build_base())
    mq = ccall(:jl_set_membership_query_world, UInt, (UInt,), world)
    codeinfos = []
    try
        empty!(CC.CLOSED_OPERATION_INSTANCES); CC.closed_used_reset!()
        rounds = 0
        while true
            empty!(CC.CLOSED_CANDIDATE_COUNTS)
            codeinfos = []
            interp = CC.NativeInterpreter(world; inf_params = CC.InferenceParams(; force_enable_inference = true), closed = owner)
            q = CC.CompilationQueue(; interp); append!(q, Any[mi])
            lq = CC.CompilationQueue(; interp)
            CC.compile!(codeinfos, q; invokelatest_queue = lq, external_linkage = false)
            CC.compile!(codeinfos, lq; invokelatest_queue = lq, external_linkage = false)
            CC.closed_note_used!(codeinfos)
            println("round ", rounds + 1, " (no member a fact: ", CC.CLOSED_NO_MEMBER[], "): ", count(x -> x isa Core.CodeInstance, codeinfos), " instances")
            show === nothing || for x in codeinfos
                x isa Core.CodeInstance && occursin(show, string(CC.get_ci_mi(x))) &&
                    println("  ", CC.get_ci_mi(x), " => ", x.rettype, " [ci ", objectid(x), " worlds ", x.min_world, ":", x.max_world, "]")
            end
            showcode === nothing || for i in 1:length(codeinfos)-1
                x = codeinfos[i]
                x isa Core.CodeInstance && occursin(showcode, string(CC.get_ci_mi(x))) && println(codeinfos[i+1])
            end
            for (X, n) in CC.CLOSED_CANDIDATE_COUNTS
                c = CC.closed_candidates(X)
                println("  ", X, ": inferred with ", n, ", now ", c === nothing ? "?" : length(c))
            end
            ((rounds < 16 && CC.closed_candidates_grew()) || CC.closed_no_member_round(rounds)) || break
            rounds += 1
            stale = Base.IdSet{Any}()
            CC.closed_build_reinfer!(world, stale, owner)
            n0 = length(stale)
            CC.closed_invalidate_callers!(codeinfos, stale, world, owner)
            show === nothing || println("  stale: ", n0, " noted, ", length(stale), " with callers; ",
                join(unique([string(CC.get_ci_mi(c).def.name) for c in stale if c isa Core.CodeInstance]), " "))
        end
        raising && for x in codeinfos
            x isa Core.CodeInstance && x.rettype === Union{} && println("  raises: ", CC.get_ci_mi(x))
        end
        return codeinfos
    finally
        for x in codeinfos
            x isa Core.CodeInstance && x.owner === owner && CC.closed_end_code!(x, world)
        end
        CC.closed_used_reset!()
        ccall(:jl_set_membership_query_world, UInt, (UInt,), mq)
    end
end
