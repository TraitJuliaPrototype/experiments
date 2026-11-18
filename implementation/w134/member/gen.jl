# E-360: generate the member packages into <dir> (implicit-environment packages, found through JULIA_LOAD_PATH).
#     julia gen.jl <dir>
# Each member in two or three forms: 0, the declaration alone; 1 (and 2), with the library's work on it in the image.
dir = ARGS[1]
pkg(name, body) = (d = joinpath(dir, name, "src"); mkpath(d); write(joinpath(d, name * ".jl"), "module $name\n" * body * "\nend\n"))
colwork(TB) = """
let t = $TB.table("a" => collect(1.0:200.0), "r" => Rep(2.5, 200), "k" => Rep(7, 200))
    $TB.summary_text(t); $TB.head($TB.sortby(t, "a"), 5); $TB.floats(t, "r"); $TB.floats(t, "k")
end
"""
coltrait = """
using TraitWorld
using TraitTables
import TraitTables.TableCore: Column, nrows, cell
@trait_module
export Rep
struct Rep{T}; x::T; n::Int; end
Base.eltype(::Type{Rep{T}}) where {T} = T
@implement Column{T} Rep{T} where {T} begin
    nrows(c) = c.n
    cell(c, i) = c.x
end
"""
colplain = """
using PlainTables
export Rep
struct Rep{T} <: AbstractVector{T}; x::T; n::Int; end
Base.size(c::Rep) = (c.n,)
Base.getindex(c::Rep, i::Int) = c.x
"""
pkg("ColA0", coltrait); pkg("ColA1", coltrait * colwork("TraitTables"))
pkg("PColA0", colplain); pkg("PColA1", colplain * colwork("PlainTables"))
prob = """
using TraitWorld
using TraitDifferentialEquations
@trait_module
export LP, lorenz_lp!, problem
struct LP; s::Float64; r::Float64; b::Float64; end
lorenz_lp!(du, u, p, t) = (du[1] = p.s * (u[2] - u[1]); du[2] = u[1] * (p.r - u[3]) - u[2]; du[3] = u[1] * u[2] - p.b * u[3]; nothing)
problem() = ODEProblem(lorenz_lp!, [1.0, 0.0, 0.0], (0.0, 2.0), LP(10.0, 28.0, 8 / 3))
"""
w1 = "solve(problem(), Tsit5(); saveat = collect(0.0:0.1:2.0), reltol = 1e-6, abstol = 1e-8)\n"
w2 = "solve(problem(), Rodas5(); saveat = collect(0.0:0.1:2.0), reltol = 1e-6, abstol = 1e-8)\n"
pkg("ProbA0", prob); pkg("ProbA1", prob * w1); pkg("ProbA2", prob * w1 * w2)
