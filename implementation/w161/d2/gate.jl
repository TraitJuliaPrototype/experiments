# W-161, E-500: D-2's gate, `Callable` is a contract at the box (traits §9; compiler §7.4; lowering §9).
# Every function is a member of every `Callable{A, S}`, subtyping reads no method; the signature is checked where a
# function is boxed (the MethodError of the call that passes it) or a wrapper enters (and its inferred result
# against `S`, GT-24 (b)); the result asserted on every call of a box; a callable struct joins by
# `@implement Callable T`; a method definition ends no code through a membership of `Callable`.
#     julia --project=<TraitWorld tree> gate.jl
using TraitWorld, Test
latest(f, args...) = Base.invokelatest(f, args...)
thrown(f, args...) = try latest(f, args...); nothing catch e; e end
function code_of(f, T)
    for m in methods(f), mi in Base.specializations(m)
        (mi isa Core.MethodInstance && mi.specTypes === Tuple{typeof(f), T.parameters...} && isdefined(mi, :cache)) || continue
        ci = mi.cache
        while true
            ci.max_world == typemax(UInt) && return ci
            isdefined(ci, :next) || break; ci = ci.next
        end
    end
    return nothing
end

module G
using TraitWorld
colmap(f::Callable{Tuple{Float64}, Float64}, x::Float64) = f(x)
form(f::Callable{Tuple{Float64}, Float64}) = f isa Dynamic ? :box : f isa TraitWorld.Compiled ? :wrapper : :plain
struct Doubler; end
(::Doubler)(x::Float64) = 2x
struct Halver; end
(::Halver)(x::Float64) = x / 2
@implement Callable Halver
only_float(x::Float64) = x
g(f::Callable{Tuple{Float64}, Float64}) = 1
hh() = g(only_float)
gi(f::Callable{Tuple{Int}, Int}) = 1
hi() = gi(only_float)
end

@testset "D-2: Callable is a contract at the box" begin
    # every function is a member of every instance; subtyping reads no method
    @test typeof(sin) <: Callable{Tuple{Float64}, Float64}
    @test typeof(uppercase) <: Callable{Tuple{Float64}, Float64}          # no method there: a member still
    @test typeof(G.only_float) <: Callable{Tuple{String}, Symbol}
    @test !(Int <: Callable{Tuple{Float64}, Float64})
    @test !(G.Doubler <: Callable{Tuple{Float64}, Float64})              # a callable struct: not before its declaration
    @test G.Halver <: Callable{Tuple{Float64}, Float64}                  # declared
    # the box: the signature checked where the function is boxed, at the call that passes it
    @test latest(G.colmap, sin, 1.0) == sin(1.0)
    @test latest(G.form, sin) === :box
    e = thrown(G.colmap, uppercase, 1.0)
    @test e isa MethodError && e.f === G.colmap
    m = sprint(showerror, e)
    println(m)
    @test occursin("none of its methods takes", m)
    # the result asserted on every call of a box
    @test thrown(G.colmap, x -> "s", 1.0) isa TypeError
    # the wrapper: checked where it enters, its calls the function's own
    @test latest(G.colmap, TraitWorld.ByType.compiled_for(sin), 1.0) == sin(1.0)
    @test latest(G.form, TraitWorld.ByType.compiled_for(sin)) === :wrapper
    e = thrown(G.colmap, TraitWorld.ByType.compiled_for(uppercase), 1.0)
    @test e isa MethodError
    e = thrown(G.colmap, TraitWorld.ByType.compiled_for(x::Float64 -> "s"), 1.0)
    @test e isa TypeError                                                # GT-24 (b): its result inferred outside S
    println(sprint(showerror, e))
    # a callable struct by its declaration
    @test latest(G.colmap, G.Halver(), 4.0) == 2.0
    @test thrown(G.colmap, G.Doubler(), 4.0) isa MethodError             # not declared: no method takes it
    # a box written out
    @test Dynamic{Callable{Tuple{Float64}, Float64}}(sin) isa Dynamic
    @test thrown(Dynamic{Callable{Tuple{Float64}, Float64}}, uppercase) isa MethodError
    # a method definition begins and ends no membership of Callable; code rests on the function's dispatch at `A`
    # only through the box's test, a fact with its edge: a method at another signature ends nothing
    @test latest(G.hh) == 1
    ci = code_of(G.hh, Tuple{})
    @test ci !== nothing
    @eval G only_float(x::String) = x
    @test ci.max_world == typemax(UInt)
    @test thrown(G.hi) isa MethodError                                   # no method at Tuple{Int}: refused
    @eval G only_float(x::Int) = 2x
    @test latest(G.hi) == 1                                              # the test, a fact, follows the new method
    @test typeof(G.only_float) <: Callable{Tuple{Symbol}, Symbol}        # membership never changed
end
