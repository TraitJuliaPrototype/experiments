# E-364: `make_executable` and `make_library` (traits §16) on a program written in a file.
#     julia --project=../../../TraitWorld-unified make.jl
using TraitWorld
include(joinpath(@__DIR__, "apps", "program.jl"))
out = joinpath(@__DIR__, "out"); mkpath(out)
exe = make_executable(shapes_main, joinpath(out, "made"))
println("make_executable: ", filesize(exe), " bytes")
print(read(`$exe`, String))
lib = make_library([total_area => (Cdouble, (Cint,))], joinpath(out, "libmade.so"))
println("make_library: ", filesize(lib), " bytes")
csrc = joinpath(out, "caller.c")
write(csrc, "#include <stdio.h>\ndouble total_area(int);\nint main(void) { printf(\"total_area(2) = %.4f\\n\", total_area(2)); return 0; }\n")
run(`$(get(ENV, "CC", "cc")) -o $(joinpath(out, "caller")) $csrc -L$out -lmade -Wl,-rpath,$out`)
print(read(`$(joinpath(out, "caller"))`, String))
e = try make_executable(untyped_main, joinpath(out, "untyped")); nothing catch err; err end
println("an untyped program: ", e isa BuildError ? first(sprint(showerror, e), 110) : e)
e = try make_executable(args -> 0, joinpath(out, "anonymous")); nothing catch err; err end
println("an anonymous function: ", e isa Exception ? first(sprint(showerror, e), 160) : e)
