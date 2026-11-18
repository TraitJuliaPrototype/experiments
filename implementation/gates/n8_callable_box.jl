# Gate (W-164; traits §9; compiler §6.3, §7.4 "The check at the box"; lowering §9): `Callable{A, S}`'s contract is
# checked at the box, by the library. A plain function given at `Callable{A, S}` is boxed by the forwarder, and the box
# is made only for a function with a method at `A`: else the `MethodError` of the call that passes it. A call of the
# box asserts its arguments to `A` (`MethodError`) and its result to `S` (`TypeError`), never converted, whether the
# result is returned or used, the function a constant of the caller or not; `A` and `S` at the method's variables,
# fixed by the other arguments. A wrapper (`compiled_for(f)`) is checked where it enters (a method at `A`, its result
# inferred at `A` able to be an `S`); its calls are the function's own, not asserted (GT-24).
# W-113's cases of `n8_callable.jl` that the box holds today; `w161/d2/gate.jl` (E-500) holds the others
# (a callable struct by its declaration, the box written out, a definition that ends no code).
# project: TraitWorld
#     julia --project=<TraitWorld tree> n8_callable_box.jl
using TraitWorld
const cf = TraitWorld.ByType.compiled_for              # the wrapper, made in plain code
raises(E, f, args...) = try Base.invokelatest(f, args...); false catch e; e isa E end

module B
using TraitWorld
const C = Callable
form(f::C{Tuple{Int}, Int}) = f isa Dynamic ? :box : f isa TraitWorld.Compiled ? :wrapper : :plain
call1(f::C{Tuple{Int}, Int}) = f(1)
strresult(x::Int) = "s"
viaconst() = call1(strresult)                          # the function a constant of the caller
call2(f::C{Tuple{Float64}, Float64}, x::Float64) = f(x) + 1     # the result used, not returned
intresult(x::Float64) = 1
okresult(x::Float64) = 2x
wide(x) = 1
callwide(f::C{Tuple{Int}, Int}) = f(1.5)               # a call outside A
samet(f::C{Tuple{T}, T}, x::T) where {T} = f(x)        # A and S at the method's variable, fixed by x
retain(f::C{Tuple{T}, Bool}, xs::Vector{T}) where {T} = filter(f, xs)
end


# a plain function is boxed; the box's calls are the function's
@assert B.form(abs) === :box && B.call1(abs) == 1
@assert B.form(cf(abs)) === :wrapper && B.call1(cf(abs)) == 1

# the signature checked where the function is boxed: the MethodError of the call that passes it
e = try B.call1(uppercase); nothing catch err; err end
@assert e isa MethodError && e.f === B.call1 "refused at the call that passes it: $e"
@assert raises(MethodError, B.retain, uppercase, [1, 2]) "the box at the signature the other argument gives"
@assert B.retain(iseven, [1, 2, 3, 4]) == [2, 4]

# the result asserted to S on return, never converted, however the box's call is used
@assert raises(TypeError, B.call1, B.strresult) "returned"
@assert raises(TypeError, B.viaconst) "the function a constant of the caller"
@assert raises(TypeError, B.call2, B.intresult, 1.0) "used, not returned: an Int is not converted to Float64"
@assert B.call2(B.okresult, 1.0) == 3.0
@assert B.samet(B.okresult, 1.0) == 2.0 && raises(TypeError, B.samet, B.intresult, 1.0) "S at the method's variable"

# the arguments asserted to A at a call of the box, though the function has a method for the call
@assert raises(MethodError, B.callwide, B.wide) "a call of the box outside A"

# a wrapper: checked where it enters; its calls are the function's own, not asserted (GT-24)
@assert raises(MethodError, B.call1, cf(uppercase)) "no method at A: refused at entry"
@assert raises(TypeError, B.call2, cf(B.intresult), 1.0) "its result inferred at A is outside S: refused at entry (GT-24 (b))"
@assert B.call2(cf(B.okresult), 1.0) == 3.0
@assert B.callwide(cf(B.wide)) == 1 "the wrapper's call is the function's own: not asserted to A"

println("n8_callable_box: OK")
