function (@main)(args::Vector{String})::Cint
    println(Core.stdout, repeat('-', length(args) + 3))
    return 0
end
