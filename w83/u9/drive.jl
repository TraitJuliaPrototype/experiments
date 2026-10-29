# U9 driver: run a session file in this process (each top-level expression as the REPL evaluates it:
# soft scope, `Main`, the latest world; errors shown and the session continues; U9_MODE=include: as a
# script), then the census.
#     julia --project=<env> drive.jl <label> <session.jl> [the session's arguments…]
using REPL
const U9_LABEL = ARGS[1]
const U9_FILE = abspath(ARGS[2])
let rest = ARGS[3:end]; empty!(ARGS); append!(ARGS, rest); end     # the session's own arguments
if get(ENV, "U9_MODE", "repl") == "include"     # a script: run as `julia script.jl` would
    try Base.include(Main, U9_FILE) catch e; println("U9 script raised: ", sprint(showerror, e)[1:min(end, 300)]) end
else let src = read(U9_FILE, String), pos = 1, nerr = 0
    while pos <= ncodeunits(src)
        start = pos
        ex, pos = Meta.parse(src, pos; raise = false, filename = U9_FILE)
        ex === nothing && continue
        ex == :(exit()) && continue                                  # the census runs before the end
        try
            v = Base.invokelatest(Core.eval, Main, REPL.softscope(ex))
            # shown as the REPL shows it, unless the input ends with `;`
            if v !== nothing && !REPL.ends_with_semicolon(src[start:prevind(src, pos)])
                Base.invokelatest(show, IOContext(stdout, :limit => true, :displaysize => (40, 120)), MIME"text/plain"(), v)
                println()
            end
        catch e
            nerr += 1
            println("U9 entry raised: ", sprint(showerror, e)[1:min(end, 200)])
        end
    end
    println("U9 session done: ", U9_LABEL, ", entries that raised: ", nerr)
end end
include(joinpath(@__DIR__, "census.jl"))
U9Census.run(U9_LABEL)
