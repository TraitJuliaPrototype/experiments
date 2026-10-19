# The raw invalidation log of one load after the control's work: which compiled code a package's
# methods invalidate, and through which edge.   julia [-J facts/sys.so] invtree.jl <csv> <package>
const csv = ARGS[1]
using CSV, DataFrames
println("mode: ", Base.Compiler.NativeInterpreter().facts ? "all (facts)" : "plain")
w = @eval () -> (df = CSV.read($csv, DataFrame); describe(df); c = names(df)[1]; sort(df, c); combine(groupby(df, names(df)[end]), c => sum); nothing)
Base.invokelatest(w)
invs = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
Core.eval(Main, Meta.parse("using " * ARGS[2]))
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
sh(x) = x isa Core.MethodInstance ? "MI " * string(x.specTypes) * (x.def isa Method ? "  [" * string(x.def.module) * "]" : "") :
        x isa Core.CodeInstance ? "CI " * sh(x.def isa Core.MethodInstance ? x.def : x.def.def) * " owner=" * repr(x.owner) :
        x isa Method ? "METHOD " * string(x.module) * "." * string(x.name) * " " * string(x.sig) : repr(x)
for (i, x) in enumerate(invs)
    println(lpad(i, 5), "  ", first(sh(x), 260))
end
