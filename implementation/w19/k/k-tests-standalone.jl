# The testsets of T11 to T17 (k-tests/), run standalone on a built tree: the subtype.jl ones in RowTests' module,
# the show.jl one, and the Compiler ones with the names their files import.
#     <tree>/julia --startup-file=no experiments/implementation/w19/k/k-tests-standalone.jl
using Test
const Compiler = Base.Compiler
using .Compiler.TrimVerifier: get_verify_typeinf_trim, CallMissing
push!(ARGS, "15.jl", "11.jl", "12.jl", "14.jl", "16c.jl")
include(joinpath(@__DIR__, "k-rowtests.jl"))
for f in ("13-show.jl", "17-inference.jl", "16c-verifytrim.jl")
    println("== ", f)
    try
        @testset "$f" begin
            include(joinpath(@__DIR__, "k-tests", f))
        end
    catch e
        println("STOPPED in ", f, ": ", sprint(showerror, e)[1:min(end, 300)])
    end
end
