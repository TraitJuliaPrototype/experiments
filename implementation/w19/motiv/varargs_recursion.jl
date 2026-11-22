# W-19, P11 and P12: a varargs wrapper in a recursion (a function barrier on a tree), compiled at run
# time as a program would. Prints the time and the allocation of one walk, and the specializations
# of the wrapper.
#   julia --startup-file=no varargs_recursion.jl
abstract type S end
struct A <: S; x::Float64; end
struct G <: S; kids::Vector{S}; end
@inline wrap(f::F, r, args...) where {F} = f(r, args...)
visit(a::A, h::Float64, k::Int) = a.x + h
function visit(g::G, h::Float64, k::Int)
    for c in g.kids
        h = wrap(visit, c, h, k)
    end
    return h
end
n = 10^5
big = G(S[isodd(i) ? A(1.0) : G(S[A(2.0)]) for i in 1:n])
visit(big, 0.0, 1)
a = @allocated visit(big, 0.0, 1)
t = minimum(@elapsed(visit(big, 0.0, 1)) for _ in 1:5)
println("visit over ", n, " kids: ", round(1e3t; digits = 2), " ms, ", a, " bytes allocated")
println("specializations of wrap: ", join((mi.specTypes for mi in Base.specializations(only(methods(wrap)))), "; "))
