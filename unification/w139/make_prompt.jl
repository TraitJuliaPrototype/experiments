# E-364: `make_executable` for a `main` written at the prompt. The inputs below are evaluated as the
# prompt evaluates them (each its own input, its methods at "REPL[n]"), then the build replays their
# definitions (`session`). At a real prompt the inputs are the prompt's history, and `session` is not given.
#     julia --project=../../../TraitWorld-unified make_prompt.jl
using TraitWorld
const INPUTS = [
    "using TraitWorld",
    """
    @trait Shape begin
        area(s::Shape)::Float64
    end""",
    "struct Circle; r::Float64; end",
    "struct Square; a::Float64; end",
    "@implement Shape Circle begin\n    area(c) = pi * c.r^2\nend",
    "@implement Shape Square begin\n    area(s) = s.a^2\nend",
    "total(v::Vector{Shape}) = (t = 0.0; for s in v; t += area(s); end; t)",
    "shapes = Shape[Circle(1.0), Square(2.0)]",              # a global of the session: not replayed
    "total(shapes)",                                          # a call: not replayed
    "function main(args::Vector{String})\n    v = Shape[Circle(1.0), Square(2.0), Circle(0.5)]\n    println(Core.stdout, \"total area \", round(total(v); digits = 4))\n    return 0\nend",
]
for (i, s) in enumerate(INPUTS)
    include_string(Main, s, "REPL[$i]")
end
out = joinpath(@__DIR__, "out"); mkpath(out)
exe = make_executable(main, joinpath(out, "made_prompt"); session = INPUTS)
println("make_executable, a main written at the prompt: ", filesize(exe), " bytes")
print(read(`$exe`, String))
println("in the session: total area ", round(Base.invokelatest(total, Shape[Circle(1.0), Square(2.0), Circle(0.5)]); digits = 4))
