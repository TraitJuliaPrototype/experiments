# AC-16 (§4c, D8's blessing; re-judged to traits §14 and compiler §2.7 with W-114): fully typed mode.
# A method under `@enforce_fully_typed` whose code has a run-time site raises NotFullyTypedError when
# it runs at that signature, naming the call; the same body outside the mode runs; under the facts
# mode alone it runs; in the mode and fully typed it runs. Never fires for plain or facts frames.
include("ac_util.jl")
push!(LOAD_PATH, normpath(joinpath(@__DIR__, "..", "..", "..", "..", "TraitWorld-unified")))
using TraitWorld

# (re-judged with W-142, traits §14: the fault is what a closed build refuses. A function with one
# method takes a value typed `Any` in a build, so the call is resolved there, and a few methods are
# branched over; one with more methods than inference follows is not)
sink16(a::Int) = a
sink16(a::String) = a
sink16(a::Float64) = a
sink16(a::Symbol) = a
sink16(a::Char) = a
one16(a) = a

@enforce_fully_typed cone16(v::Vector{Any}) = one16(v[1])     # the mode + a call a build resolves: runs
@assert cone16(Any[1]) == 1 "a call that a closed build resolves is no fault"

@enforce_fully_typed cbad16(v::Vector{Any}) = sink16(v[1])    # the mode + a call a build refuses
err = try
    cbad16(Any[1])
    nothing
catch e
    e
end
@assert err !== nothing "the mode + a run-time site raises"
@assert err isa NotFullyTypedError "the named error type, got $(typeof(err))"
@assert occursin("sink16", sprint(showerror, err)) "the message names the call"
println("OBSERVED NotFullyTypedError: ", sprint(showerror, err))

cplain16(v::Vector{Any}) = sink16(v[1])      # outside the mode: runs
@assert cplain16(Any[1]) == 1 "outside the mode it runs"

cfacts16(v::Vector{Any}) = sink16(v[1])      # facts-marked, not in the mode: runs
mark!(cfacts16)
@assert cfacts16(Any[1]) == 1 "facts without the mode does not enforce"

@enforce_fully_typed cok16(v::Vector{Int}) = v[1] + 1    # the mode, fully typed: runs
@assert cok16([1]) == 2 "the mode and fully typed code runs"

ac_finish(@__FILE__)
