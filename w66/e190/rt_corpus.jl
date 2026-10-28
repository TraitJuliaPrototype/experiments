# E-190 (W-22, open issue 30): run-time `return_type` against plain inference's answer, which the compile-time
# fold uses, over the session's own facts methods. After the workload: every specialization of a facts method
# with a valid facts CodeInstance at a dispatch tuple whose function is a singleton is a query. For each, the
# run-time answer (`Core.Compiler.return_type`), plain inference's (`PlainRTInterp`), and facts inference's
# (the CodeInstance's result). Prints how many run-time answers differ from plain's, examples, and the time.
#     julia --project=<env> rt_corpus.jl <workload script> <outdir>   (from experiments/ttfx)
const CC = Base.Compiler
const _SCRIPT, _OUT = ARGS[1], ARGS[2]
empty!(ARGS); push!(ARGS, _OUT)
include(joinpath(pwd(), _SCRIPT))
let
    sigs = Any[]
    Base.visit(Core.methodtable) do m
        ccall(:jl_method_is_facts, Cint, (Any,), m) != 0 || return
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance && isdefined(mi, :cache) || continue
            ci = mi.cache; ok = false; frt = nothing
            while ci isa Core.CodeInstance
                ci.owner === :facts && ci.max_world == typemax(UInt) && (ok = true; frt = ci.rettype)
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
            ok || continue
            T = mi.specTypes
            T isa DataType && CC.isdispatchtuple(T) || continue
            ft = T.parameters[1]
            isdefined(ft, :instance) || continue
            push!(sigs, (T, frt))
        end
    end
    world = Base.get_world_counter()
    differ = 0; wider = 0; ex = String[]
    t_rt = 0.0
    for (T, frt) in sigs
        f = T.parameters[1].instance
        tt = Tuple{T.parameters[2:end]...}
        t0 = time_ns()
        rt = Core.Compiler.return_type(f, tt)
        t_rt += (time_ns() - t0) / 1e9
        pl = CC._return_type(CC.PlainRTInterp(world), T)
        if rt !== pl
            differ += 1
            CC.:⊑(pl, rt) && rt !== pl && (wider += 1)
            length(ex) < 8 && push!(ex, string(first(string(T), 120), "  run time ", rt, "  plain ", pl, "  facts ", frt))
        end
    end
    println("R julia ", Base.GIT_VERSION_INFO.commit_short, "; queries ", length(sigs), "; run-time answer differs from plain inference's: ",
            differ, " (wider ", wider, "); run-time queries took ", round(t_rt; digits = 2), " s")
    foreach(e -> println("R   ", e), ex)
end
