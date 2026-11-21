# C-157 in the tutorial's own session: runs experiments/docs-examples/tutorial.jl up to §14's `passes` check, then
# prints which check raised (the TypeError's fields) and the message. Run from the library's tree (see README).
const DOCS = joinpath(@__DIR__, "..", "..", "..", "docs-examples")
src = read(joinpath(DOCS, "tutorial.jl"), String)
lines = split(src, '\n')
stop = findfirst(l -> startswith(l, "deviation(\"§14 a function known only by its signature"), lines)
text = join(lines[1:stop-1], '\n')
text = replace(text, "include(joinpath(@__DIR__, \"common.jl\"))" => "include(joinpath(\"$DOCS\", \"common.jl\"))")
include_string(Main, text, joinpath(DOCS, "tutorial.jl"))
println("\n== §14 passes(Callable{Tuple{Float64}, Bool}[x -> 1], 2.0)")
println("   ", e isa TypeError ? "TypeError(func=$(repr(e.func)), context=$(repr(e.context)), expected=$(e.expected), got=$(repr(e.got)))" : repr(e))
println("   showerror: ", msg(e))
