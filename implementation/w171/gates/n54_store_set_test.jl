# Gate (compiler §4.8; E-544): a store into storage typed by a set (`setfield!` at a field typed `X`, `memoryrefset!`
# into a `Memory{X}`) of a value whose type is no member yet: inference does not prove the store throws (no frame
# records the pair), and the store's test is not consistent, so no caller evaluates it at compile time. Once the
# membership is declared the compiled stores succeed (the process stops in `unreachable` on a build without the rule).
# A candidate for `gates/`; fails on `next` 3e9c193025.
#     julia --project=experiments/implementation n54_store_set_test.jl
using Traits
@trait X
struct S end
struct Ph{T} end
mutable struct MB; v::X; MB() = new(); end
mutable struct MP; v::Ph{<:X}; MP() = new(); end
stf(x) = (m = MB(); setfield!(m, :v, x); true)
mrs(x) = (Core.memoryrefset!(Core.memoryrefnew(Memory{X}(undef, 1)), x, :not_atomic, true); true)
stp(x) = (m = MP(); setfield!(m, :v, x); true)        # a singleton value: a caller may evaluate it at compile time
rtp(x) = stp(x)
tryf(f, x) = try f(x) catch e; e isa TypeError ? :TypeError : rethrow() end
@assert tryf(stf, S()) === :TypeError && tryf(mrs, S()) === :TypeError && tryf(rtp, Ph{S}()) === :TypeError
@assert Base.return_types(stf, (S,)) == [Bool] && Base.return_types(rtp, (Ph{S},)) == [Bool]
@implement X S
@assert stf(S()) && mrs(S()) && rtp(Ph{S}()) "the stores compiled before the membership"
println("n54_store_set_test: OK")
