# W-158, fourth part (E-510; compiler §7.1, §7.6): an operation's call typed by its declared result, a trait. With one
# member, a family's (counted by use), the optimizer inlines the lone branch, and no statement of the code forgets its value: the declared result's
# members by use must count it, else the trait's operation is a "no method" fact and the binary raises where the
# session returns (the ODE program's `linfactor(ls, W)::Solvable{Float64}`, then `ldiv!`).
# `julia --project=<TraitWorld> apps/f-result.jl` runs `main` in a session.
using TraitWorld
@trait Fact begin
    solvewith(f::Fact, b::Float64)::Float64
end
struct LUish{T}; d::T; end
solvewith(f::LUish, b::Float64) = b / f.d
@implement Fact LUish{T} where {T}
@trait Maker begin
    make(m::Maker, d::Float64)::Fact
end
struct Dense end
make(::Dense, d::Float64) = LUish(d)
@implement Maker Dense
@noinline run(ms::Vector{Maker}, d::Float64) = (s = 0.0; for m in ms; s += solvewith(make(m, d), 6.0); end; s)
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, "result ", run(Maker[Dense()], Float64(length(args) + 2)))
    return 0
end
