# The type-closure report (E-322's pattern, found again by E-344): closures of a module compiled once per
# type they capture. A closure over a type (`filter!(r -> r.trait === X, …)` with `X` a type) has the
# captured value's type as a parameter, so it is compiled anew for each trait, member or pattern it
# meets. Reads a compile trace (`--trace-compile=<log> --trace-compile-timing`) and lists, per closure of
# the module, how many instances specialize on a `Type{…}` parameter and the compile time they took.
# A report: it asserts nothing.
#
# Usage: julia type_closures.jl <trace.log> [Module] [n]
log = ARGS[1]
mod = length(ARGS) >= 2 ? ARGS[2] : "TraitWorld"
nshow = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 20
re = Regex("^#=\\s*([0-9.]+) ms =# precompile\\(Tuple\\{(.*)\\}\\)")
clo = Regex(mod * "\\.var\"#([^\"#]+)##\\d+#[^\"]*\"\\{(.*?)\\}")
byname = Dict{String, Tuple{Int, Float64}}()
total = 0
for line in eachline(log)
    m = match(re, line)
    m === nothing && continue
    ms, sig = parse(Float64, m[1]), m[2]
    c = match(clo, sig)
    c === nothing && continue
    occursin("Type{", c[2]) || continue
    n, t = get(byname, c[1], (0, 0.0))
    byname[c[1]] = (n + 1, t + ms)
    global total += 1
end
println("closures of $mod compiled at a captured Type{…}: ", total, " instances")
for (name, (n, t)) in sort(collect(byname); by = x -> -x[2][2])[1:min(nshow, end)]
    println("  ", rpad(name, 40), lpad(n, 5), " instances ", lpad(round(t, digits = 1), 8), " ms")
end
