# E-361 (1): the control.
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, "Hello, world!")
    return 0
end
