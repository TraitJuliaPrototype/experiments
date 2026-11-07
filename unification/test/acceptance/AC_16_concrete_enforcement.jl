# AC-16 (§4c, D8's blessing; re-judged to traits §14 and compiler §2.7 with W-114): fully typed mode.
# A method under `@enforce_fully_typed` whose code has a run-time site raises NotFullyTypedError when
# it runs at that signature, naming the call; the same body outside the mode runs; under the facts
# mode alone it runs; in the mode and fully typed it runs. Never fires for plain or facts frames.
include("ac_util.jl")
push!(LOAD_PATH, normpath(joinpath(@__DIR__, "..", "..", "..", "..", "TraitWorld-unified")))
using TraitWorld

sink16(a) = a

@enforce_fully_typed cbad16(v::Vector{Any}) = sink16(v[1])    # the mode + a run-time site
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
