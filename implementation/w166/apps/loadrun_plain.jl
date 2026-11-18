# W-166 (open issue 241): the control: plain code run while the build loads it (a loop over a `Vector{Any}`).
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, "plain ", sum([1.0, 2.0, 3.0]))
    return 0
end
v = Any[1.0, "a", 2]; println(Core.stdout, "at load: ", sum(x isa Float64 ? x : 0.0 for x in v))
main(String[])
