# E-361 (2): PlainPlots drawing lines and points to a PNG.
using PlainPlots; const TraitMakie = PlainPlots
function (@main)(args::Vector{String})::Cint
    xs = collect(range(0.0, 10.0; length = 200))
    f = TraitMakie.lines(xs, sin.(xs); color = :blue)
    TraitMakie.scatter!(f, xs[1:10:end], cos.(xs[1:10:end]); color = :red)
    TraitMakie.save(isempty(args) ? "plot.png" : args[1], f)
    println(Core.stdout, "wrote ", isempty(args) ? "plot.png" : args[1])
    return 0
end
include("jllhole.jl")
