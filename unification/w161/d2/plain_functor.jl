# W-161, E-500, GT-32 (open issue 227): a plain package's callable struct at a `Callable` argument. An
# interpolation object of Interpolations.jl (plain code; its type is no `Function`) passed where
# `Callable{Tuple{Float64}, Float64}` is declared; then the same after the caller's own declaration.
#     julia --project=<env with Interpolations and TraitWorld> plain_functor.jl
using TraitWorld, Interpolations
at(g::Callable{Tuple{Float64}, Float64}, x::Float64) = g(x)
itp = linear_interpolation([0.0, 1.0, 2.0], [0.0, 10.0, 40.0])
println("the interpolation's type: ", nameof(typeof(itp)), "; a Function: ", itp isa Function, "; itp(1.5) = ", itp(1.5))
println("typeof(itp) <: Callable{Tuple{Float64}, Float64}: ", typeof(itp) <: Callable{Tuple{Float64}, Float64})
e = try at(itp, 1.5); nothing catch err; err end
println("at(itp, 1.5): ", e === nothing ? "ran" : first(split(sprint(showerror, e), '\n')))
# the caller declares the plain package's type (a pirate declaration: it owns neither)
r = try
    @eval @implement Callable Interpolations.Extrapolation
    "declared"
catch err
    first(split(sprint(showerror, err), '\n'))
end
println("@implement Callable Interpolations.Extrapolation by the caller: ", r)
e = try Base.invokelatest(at, itp, 1.5) catch err; err end
println("at(itp, 1.5) after: ", e isa Exception ? first(split(sprint(showerror, e), '\n')) : e)
println("a closure instead: at(x -> itp(x), 1.5) = ", at(x -> itp(x), 1.5))
