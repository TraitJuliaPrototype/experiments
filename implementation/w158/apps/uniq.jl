# W-158, part B: plain Julia's hole in a JLL's `__init__`, without the JLL: `unique!` of a `Vector{String}`
# (JLLWrappers' `wrapper_generators.jl` 64) calls `issorted(itr, rev = true)`.
function (@main)(args::Vector{String})::Cint
    v = String["/usr/lib", "/opt/lib", "/usr/lib"]
    append!(v, args)
    unique!(v)
    println(Core.stdout, length(v), " ", v[1])
    return 0
end
