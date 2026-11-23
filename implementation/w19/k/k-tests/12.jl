# `Callable{A, S}`: every function is a member of every instance by one entry, a callable type by its own
# declaration; a call of a function known only by the signature checks its arguments against `A`
struct CaHalver end
(::CaHalver)(x::Float64) = x / 2
struct CaDoubler end
(::CaDoubler)(x::Float64) = 2x
member!(Core.Callable, CaHalver)                       # the bare set: every instance
cag(x::Int) = x + 1
cag(x::String) = 0                                     # a method outside the signature the caller states
cacall(@nospecialize(f::Core.Callable{Tuple{Int}, Int}), x) = f(x)
cacallstr(@nospecialize(f::Core.Callable{Tuple{Int}, Int})) = f("s")

@testset "Callable{A, S}" begin
    @test typeof(abs) <: Core.Callable{Tuple{Int}, Int}
    @test typeof(uppercase) <: Core.Callable{Tuple{Int}, Int}   # whatever its methods
    @test Function <: Core.Callable{Tuple{Int}, Int}
    @test !(Int <: Core.Callable) && !(1 isa Core.Callable)
    @test CaHalver <: Core.Callable{Tuple{Float64}, Float64} && !(CaDoubler <: Core.Callable)
    @test cacall(cag, 1) == 2
    @test_throws MethodError cacall(cag, "s")          # outside `A`: no method, though `cag` has one there
    @test_throws MethodError cacallstr(cag)
end
