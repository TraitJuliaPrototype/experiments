# W-19 (eighth part): the rows' testsets standalone, each file in a module of its own with subtype.jl's helpers.
#     <tree>/julia run-tests.jl [file ...]
using Test
const H = read(joinpath(@__DIR__, "tests", "header.jlh"), String)
files = isempty(ARGS) ? filter(f -> endswith(f, ".jl"), readdir(joinpath(@__DIR__, "tests"))) : ARGS
for f in files
    src = H * "\n" * read(joinpath(@__DIR__, "tests", f), String) * "\nend\n"
    try
        include_string(Main, src, f)
        println("FILE ", f, ": ok")
    catch e
        println("FILE ", f, ": ", sprint(showerror, e)[1:min(end, 400)])
    end
end
