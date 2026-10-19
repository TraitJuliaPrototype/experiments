# New trait code after big loads: where do 2 s go? (TDE: a new model type's @implement and first solve)
using Profile
const LOADS = get(ENV, "LOADS", "1") == "1"
LOADS && (t = @elapsed(@eval Main using CSV, DataFrames, CairoMakie); println("loads ", round(t; digits = 2), " s"))
@eval using TraitDifferentialEquations, TraitWorld
const U0 = [1.0, 0.0, 0.0]
lorenz!(du, u, p, t) = (du[1] = p[1] * (u[2] - u[1]); du[2] = u[1] * (p[2] - u[3]) - u[2]; du[3] = u[1] * u[2] - p[3] * u[3]; nothing)
solve(ODEProblem(lorenz!, U0, (0.0, 1.0), [10.0, 28.0, 8 / 3]), Tsit5())
@eval struct Lorenz; s::Float64; r::Float64; b::Float64; end
@eval TraitDifferentialEquations.rhs!(m::Lorenz, du::Vector{Float64}, u::Vector{Float64}, t::Float64) =
    (du[1] = m.s * (u[2] - u[1]); du[2] = u[1] * (m.r - u[3]) - u[2]; du[3] = u[1] * u[2] - m.b * u[3]; nothing)
function prof(label, ex)
    Profile.clear(); Profile.init(n = 10^7, delay = 0.001)
    print(label, ": "); @eval @time @profile $ex
    data = Profile.fetch(); lidict = Profile.getdict(data)
    # inclusive counts of frames by function name, top 25 (C and Julia)
    counts = Dict{String,Int}(); total = 0
    i = 1
    while i <= length(data)
        seen = Set{String}()
        while i <= length(data) && data[i] != 0
            for fr in get(lidict, data[i], ())
                k = string(fr.func, " ", basename(string(fr.file)))
                k in seen || (push!(seen, k); counts[k] = get(counts, k, 0) + 1)
            end
            i += 1
        end
        total += 1; i += 1
    end
    for (k, v) in first(sort(collect(counts); by = last, rev = true), 40)
        println("   ", lpad(v, 6), "  ", k)
    end
end
prof("@implement", :(@implement ODEModel{Float64} Lorenz))
prof("first solve", :(solve(Lorenz(10.0, 28.0, 8 / 3), U0, (0.0, 1.0), Tsit5())))
