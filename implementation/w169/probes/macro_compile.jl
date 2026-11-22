# W-169: what Julia compiles to expand `@static` and `(@main)` in a fresh process (the demonstrators' programs use both
# at top level), and Base's instances the system image holds without machine code (PE-32), by the dump of code
# generation.      julia probes/macro_compile.jl
io = open(tempname(), "w+"); ccall(:jl_dump_compiles, Cvoid, (Ptr{Cvoid},), io.handle)
Base.cumulative_compile_timing(true); c0 = Base.cumulative_compile_time_ns()
include_string(Main, "@static if true\n x = 1\n end")
c1 = Base.cumulative_compile_time_ns()
include_string(Main, "function (@main)(args::Vector{String})::Cint\n return 0\n end")
c2 = Base.cumulative_compile_time_ns()
x = Core.svec(1, 2, 3)[1:2]; for (i, s) in enumerate([:a, :b]); end
c3 = Base.cumulative_compile_time_ns()
ccall(:jl_dump_compiles, Cvoid, (Ptr{Cvoid},), C_NULL); seekstart(io)
println("MACRO @static ", round((c1[1] - c0[1]) / 1e6; digits = 1), " ms | (@main) ", round((c2[1] - c1[1]) / 1e6; digits = 1),
        " ms | getindex(svec, range), enumerate(Vector{Symbol}) ", round((c3[1] - c2[1]) / 1e6; digits = 1), " ms")
for l in eachline(io); println("  ", l); end
exit(0)
