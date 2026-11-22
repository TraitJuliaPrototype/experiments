# W-159 probe: the time of each top-level statement of a program's file (the ODE session's load mark: 2.06 s on the
# head, 0.59 s at the tag, where `using` takes 0.45-0.51 s against 0.24-0.34 s).
#     [PROFILE_STMT=<text>] julia --project=<env> defs_timed.jl <app.jl>      (the statement whose text holds <text> profiled)
f = abspath(ARGS[1]); src = read(f, String); pos = 1; line = 1
cd(dirname(f)); task_local_storage(:SOURCE_PATH, f)
while true
    global pos
    ex, nxt = Meta.parse(src, pos; raise = true)
    ex === nothing && break
    Base.cumulative_compile_timing(true); c0 = Base.cumulative_compile_time_ns()
    e = Expr(:toplevel, LineNumberNode(count(==('\n'), SubString(src, 1, pos)) + 1, Symbol(f)), ex)
    prof = occursin(get(ENV, "PROFILE_STMT", "\0"), string(ex))
    prof && (@eval using Profile; Profile.init(n = 10^7, delay = 0.001))
    t = prof ? @elapsed(@eval(Main, Profile.@profile Core.eval(Main, $(QuoteNode(e))))) : @elapsed Core.eval(Main, e)
    prof && Profile.print(IOContext(stdout, :displaysize => (1000, 200)); format = :flat, sortedby = :count, mincount = 30, C = true)
    c1 = Base.cumulative_compile_time_ns(); Base.cumulative_compile_timing(false)
    s = replace(first(string(ex isa Expr && ex.head === :macrocall ? ex : ex), 90), '\n' => ' ')
    t > 0.005 && println(lpad(round(1000t; digits = 1), 8), " ms (compiling ", round((c1[1] - c0[1]) / 1e6; digits = 1), ", recompiling ", round((c1[2] - c0[2]) / 1e6; digits = 1), ")  ", s)
    pos = nxt
end
