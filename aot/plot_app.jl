# AOT 1 (writeup/explorations/aot-under-facts.md §4): TraitMakie drawing lines and points to a PNG,
# calling Cairo directly. Built with julia-1.13's test/trimming juliac script (build.sh).
using TraitWorld, TraitMakie

function (@main)(args::Vector{String})::Cint
    xs = collect(range(0.0, 10.0; length = 200))
    f = TraitMakie.lines(xs, sin.(xs); color = :blue)
    TraitMakie.scatter!(f, xs[1:10:end], cos.(xs[1:10:end]); color = :red)
    TraitMakie.save(isempty(args) ? "plot.png" : args[1], f)
    println(Core.stdout, "wrote ", isempty(args) ? "plot.png" : args[1])
    return 0
end

# A hole outside main's walk, in plain code: JLLWrappers' `__init__` (Pango_jll, GettextRuntime_jll, …)
# calls `unique!(::Vector{String})`, whose `issorted` builds its ordering with `lt::Function`, so
# trim cannot resolve the call; at run time it is one of these two (plain Julia's trim limitation)
Base.Experimental.entrypoint(Tuple{typeof(issorted), Vector{String}, Base.Order.ForwardOrdering})
Base.Experimental.entrypoint(Tuple{typeof(issorted), Vector{String}, Base.Order.ReverseOrdering{Base.Order.ForwardOrdering}})

let r = verify_main(main, (Vector{String},); entrypoints = get(ENV, "AOT_SESSION", "0") != "1")
    nh = count(h -> !h.errorpath, r.holes)
    println(Core.stdout, "verify_main: ", nh == 0 ? "no normal-path holes" : "OPEN: $nh normal-path holes",
            ", ", length(r.targets), " targets registered as entry points, ", length(r.holes), " holes in all")
    for h in Iterators.take(filter(h -> !h.errorpath, r.holes), 30)
        println(Core.stdout, "  hole: ", h.kind, " ", h.callee, " ", h.argtypes, " at ", h.line)
    end
end
