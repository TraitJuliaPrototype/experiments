# W-166 (open issue 241): whether a trimmed build loads its program as a session does: the library's expansion hook
# at a method of an erasing trait (`Callable`: the method at the kept forms and a forwarder, 2 methods in a session).
using TraitWorld
println(Core.stdout, "erases Callable: ", TraitWorld.erases(Callable{Tuple{Int}, Int}))
g(c::Callable{Tuple{Int}, Int}) = c(1)
println(Core.stdout, length(methods(g)), " methods of g")
println(Core.stdout, "generating ", ccall(:jl_generating_output, Cint, ()), " incremental ", Base.JLOptions().incremental, " trim ", Base.JLOptions().trim)
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, g(x -> x + 1))
    return 0
end
