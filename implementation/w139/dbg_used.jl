# W-139: the members by use, seen from a session: the build's driver run on an app's `main` with the
# compiler loaded as a package, then what it noted. julia dbg_used.jl apps/<app>.jl [filter]
# the trim option before the program loads, as in a build
let i = findfirst(==(:trim), fieldnames(Base.JLOptions))
    unsafe_store!(Ptr{Int8}(cglobal(:jl_options)) + fieldoffset(Base.JLOptions, i), Int8(1))
end
include(joinpath(@__DIR__, ARGS[1]))
push!(LOAD_PATH, joinpath(ENV["TW_ROOT"], "julia-unified", "Compiler"))
using Compiler
const CC = Compiler
w = Base.get_world_counter()
mi = CC.specialize_method(only(methods(main, (Vector{String},))), Tuple{typeof(main), Vector{String}}, Core.svec())
codeinfos = CC.typeinf_ext_toplevel(Any[mi], UInt[w], CC.TRIM_UNSAFE, false)
pat = length(ARGS) >= 2 ? ARGS[2] : ""
println("instances compiled: ", count(x -> x isa Core.CodeInstance, codeinfos), "; types forgotten: ", length(CC.CLOSED_USED_TYPES), "; entries: ", length(CC.CLOSED_ENTRIES) ÷ 2)
for T in CC.CLOSED_USED_TYPES
    occursin(pat, string(T)) && !isempty(pat) && println("  ", T, "  at  ", CC.CLOSED_USED_AT[T])
end
for i in 1:2:length(CC.CLOSED_ENTRIES)
    (isempty(pat) || occursin(pat, string(CC.CLOSED_ENTRIES[i + 1]))) && println("  entry ", CC.CLOSED_ENTRIES[i], " -> ", CC.CLOSED_ENTRIES[i + 1])
end
for X in (length(ARGS) >= 3 ? [getfield(Main, Symbol(ARGS[3]))] : [])
    println("members of ", X, ": ", CC.closed_candidates(X))
end
