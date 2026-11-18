# W-94: replace the running Julia's `Compiler.ReinferUtils.verify_method` (image validation) by the one in the
# file named by W94_PATCH (the branch w94's `Compiler/src/reinfer.jl`), for this session only, so the
# patched validation runs without a build. Included before any package loads.
let f = get(ENV, "W94_PATCH", "")
    if !isempty(f)
        R = Base.Compiler.ReinferUtils
        top = Meta.parseall(read(f, String))
        n = 0
        for ex in top.args
            ex isa Expr && ex.head === :function || continue
            sig = ex.args[1]
            sig isa Expr && sig.head === :call && sig.args[1] === :verify_method || continue
            Core.eval(R, ex); n += 1
        end
        # validation runs in the compiler's fixed world (`jl_call_in_typeinf_world`); here in the latest one, to see the copy
        Core.eval(R, :(insert_backedges_typeinf(internal_methods::Vector{Any}) = Base.invokelatest(insert_backedges, internal_methods)))
        # and `require` runs in the world Base was built in (`Base._require_world_age`): move it to see the copies
        Base._require_world_age[] = Base.get_world_counter()
        println("W94_PATCH: verify_method replaced from ", f, " (", n, " method)")
    end
end
