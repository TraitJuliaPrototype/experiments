# W-158, fourth part (E-510; compiler C-86, C-155): what members by use do not count, met by a type that one entry
# makes a member of every instance. `Get` is declared callable (`@implement Callable Get`); the program reaches its one
# value only as the 4,097th element of a constant vector, past the 4,096 elements a build reads of a constant, and
# narrows it to the signature by a test. No compiled code forgets `Get`, so the build does not count it at the
# signature: the binary raises `MethodError` at the branch where the session returns (G1: an error, never another
# member's code). A function reached so was not counted before either (`Function` is abstract): the rule extends the
# gap to a concrete callable type. `julia --project=<TraitWorld> apps/f-gap.jl` runs `main` in a session.
using TraitWorld
const F = Callable{Tuple{Float64}, Float64}
double(x::Float64) = 2x
struct Get; k::Float64; end
(g::Get)(x::Float64) = g.k * x
@implement Callable Get
const GS = Callable[Any[double for _ in 1:4096]..., Get(3.0)]
@noinline use(f::F, x::Float64) = f(x)
function (@main)(args::Vector{String})::Cint
    f = GS[4096 + length(args) + 1]
    if f isa F
        println(Core.stdout, "gap ", use(f, 2.0))
    else
        println(Core.stdout, "gap: not a function at the signature")
    end
    return 0
end
