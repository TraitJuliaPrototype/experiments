# E-202 (c): a checked worker redefined so that it breaks rule 2 (a trait object passed to ordinary code),
# then called again: is the edit caught, at the redefinition or at the call?
#     julia --project=<TraitWorld> edit_case.jl
using TraitWorld
@trait_module module EditT
using TraitWorld
export Values, vals, sq
@trait Values begin
    vals(v::Values)::Vector{Float64}
end
@implement Values Vector{Float64} begin
    vals(v) = v
end
sq(v::Values) = (s = 0.0; for x in vals(v); s += abs2(x); end; s)
end
using .EditT
println("E first call: ", sq([1.0, 2.0]))
r = try
    Core.eval(EditT, :(sq(v::Values) = Float64(length(identity(v)))))   # the trait object reaches `identity`, ordinary code
    "redefinition accepted"
catch err
    "redefinition refused: " * first(sprint(showerror, err), 160)
end
println("E ", r)
c = try
    "call gives " * string(Base.invokelatest(sq, [1.0, 2.0]))
catch err
    "call refused: " * first(sprint(showerror, err), 200)
end
println("E ", c)
