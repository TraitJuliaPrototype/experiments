# The fast loop for changes to the compiler's Julia code: the in-tree julia-1.13/Compiler, loaded
# as a package and activated (about 23 s), then a script, without rebuilding the system image.
#     julia --project=devloop/env devloop/run.jl <script.jl> [args...]
# The image's own code stays as the image compiled it; code compiled in the session uses the
# loaded compiler. A change is measured on a real build once it is ready.
using Compiler
t = @elapsed Compiler.activate!(; reflection = true, codegen = true)
println("Compiler activated from ", pathof(Compiler), " in ", round(t; digits = 1), " s")
script = popfirst!(ARGS)
include(abspath(script))
