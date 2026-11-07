# W-106's second workload, shaped like ODE algorithms: a trait of operations with a value fixed
# per member (alg_order), members by their own methods, a solve function at the trait, and a
# list of Dynamic algorithms. The same program in plain Julia gives the same results.
#     <unified julia> --project=TraitWorld-unified ode.jl
using TraitWorld

module Traited
using TraitWorld
@trait ODEAlgorithm begin
    alg_order(a::ODEAlgorithm)::Int
    step!(a::ODEAlgorithm, u::Vector{Float64}, f, t::Float64, dt::Float64)::Nothing
    name(a::ODEAlgorithm)::String = "an order-$(alg_order(a)) method"
end
struct Euler end
alg_order(::Euler) = 1
step!(::Euler, u, f, t, dt) = (u .+= dt .* f(u, t); nothing)
struct Midpoint end
alg_order(::Midpoint) = 2
step!(::Midpoint, u, f, t, dt) = (k = f(u, t); u .+= dt .* f(u .+ (dt / 2) .* k, t + dt / 2); nothing)
struct RK4; tag::Symbol; end
alg_order(::RK4) = 4
name(::RK4) = "the classical Runge-Kutta method"
function step!(::RK4, u, f, t, dt)
    k1 = f(u, t); k2 = f(u .+ (dt / 2) .* k1, t + dt / 2)
    k3 = f(u .+ (dt / 2) .* k2, t + dt / 2); k4 = f(u .+ dt .* k3, t + dt)
    u .+= (dt / 6) .* (k1 .+ 2 .* k2 .+ 2 .* k3 .+ k4)
    return nothing
end
@implement ODEAlgorithm Euler
@implement ODEAlgorithm Midpoint
@implement ODEAlgorithm RK4
function solve(alg::ODEAlgorithm, f, u0::Vector{Float64}, T::Float64, n::Int)
    u = copy(u0); dt = T / n; t = 0.0
    for _ in 1:n
        step!(alg, u, f, t, dt); t += dt
    end
    return u
end
end

module Plain
abstract type ODEAlgorithm end
struct Euler <: ODEAlgorithm end
alg_order(::Euler) = 1
step!(::Euler, u, f, t, dt) = (u .+= dt .* f(u, t); nothing)
struct Midpoint <: ODEAlgorithm end
alg_order(::Midpoint) = 2
step!(::Midpoint, u, f, t, dt) = (k = f(u, t); u .+= dt .* f(u .+ (dt / 2) .* k, t + dt / 2); nothing)
struct RK4 <: ODEAlgorithm; tag::Symbol; end
alg_order(::RK4) = 4
name(a::ODEAlgorithm) = "an order-$(alg_order(a)) method"
name(::RK4) = "the classical Runge-Kutta method"
function step!(::RK4, u, f, t, dt)
    k1 = f(u, t); k2 = f(u .+ (dt / 2) .* k1, t + dt / 2)
    k3 = f(u .+ (dt / 2) .* k2, t + dt / 2); k4 = f(u .+ dt .* k3, t + dt)
    u .+= (dt / 6) .* (k1 .+ 2 .* k2 .+ 2 .* k3 .+ k4)
    return nothing
end
function solve(alg::ODEAlgorithm, f, u0::Vector{Float64}, T::Float64, n::Int)
    u = copy(u0); dt = T / n; t = 0.0
    for _ in 1:n
        step!(alg, u, f, t, dt); t += dt
    end
    return u
end
end

lorenz(u, t) = [10.0 * (u[2] - u[1]), u[1] * (28.0 - u[3]) - u[2], u[1] * u[2] - (8 / 3) * u[3]]
function run(M, wrap)
    algs = Any[M.Euler(), M.Midpoint(), M.RK4(:rk4)]
    out = Any[]
    for a in algs
        push!(out, (M.alg_order(a), M.name(a), M.solve(a, lorenz, [1.0, 0.0, 0.0], 1.0, 2000)))
    end
    ds = [wrap(a) for a in algs]
    push!(out, [M.solve(d, lorenz, [1.0, 1.0, 1.0], 0.5, 1000) for d in ds])
    return out
end

a = run(Traited, a -> Dynamic{Traited.ODEAlgorithm}(a))
b = run(Plain, identity)
println("traited orders and names: ", [x[1:2] for x in a[1:3]])
a == b || error("the workloads disagree")
println("ode: equal results")
