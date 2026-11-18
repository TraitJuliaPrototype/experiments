# W-157: the instances with the G2 bit that the nine loads end, below a port's code, and what ended them.
# The gate of stage 5: none (compiler §3.2, facts §2.2). The runtime's invalidation log names, for each
# definition a load makes, the instances it ends; the tool prints, for each instance with the bit that a
# load ends, the log's entries from the definition down to it.
#     julia --project=env_forks diag/ended_deep.jl <csv> <package>...
include(joinpath(@__DIR__, "..", "census_lib.jl"))
S = census_session(ARGS[1])
deep = [ci for ci in S.reach if bit(ci)]
println("# ended_deep | julia ", Base.GIT_VERSION_INFO.commit_short, " | reached ", length(S.reach), ", with the bit ", length(deep))
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
for p in ARGS[2:end]; Core.eval(Main, Meta.parse("using $p")); end
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
ended = [ci for ci in deep if !valid(ci)]
println("ended with the bit: ", length(ended))
for ci in ended[1:min(end, 40)]
    println("== ", first(string(ci.def.specTypes), 200), "  facts ", isfacts(ci))
    for e in ci.edges
        e isa Core.CodeInstance && println("     edge CI ", bit(e) ? "[bit] " : "", valid(e) ? "" : "(ended) ", first(string(e.def.specTypes), 150))
        e isa Core.MethodInstance && println("     edge MI ", first(string(e.specTypes), 150))
        e isa Type && println("     edge sig ", first(string(e), 150))
    end
end
# the log: a definition (a Method, with its reason) follows the instances it ended, each with its depth
mis = IdSet{Any}([ci.def for ci in ended]); cis = IdSet{Any}(ended)
i = 1; shown = 0
while i <= length(log) && shown < 30
    x = log[i]
    if (x in mis || x in cis)
        # print the cause: the next Method in the log, and the reason after it
        j = i
        while j <= length(log) && !(log[j] isa Method); j += 1; end
        if j <= length(log)
            println("ended: ", first(string(x isa Core.CodeInstance ? x.def.specTypes : x.specTypes), 120), "  <=  ", log[j],
                    j < length(log) ? string("  (", log[j+1], ")") : "")
            global shown += 1
        end
    end
    global i += 1
end
