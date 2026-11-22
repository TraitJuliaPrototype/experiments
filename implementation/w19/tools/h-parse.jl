# W-19, fourth part: parse each Julia file named; fail on a parse error (Meta.parseall returns them as
# :error and :incomplete expressions).   julia h-parse.jl <files...>
bad(e) = e isa Expr && (e.head in (:error, :incomplete) || any(bad, e.args))
global n = 0
for f in ARGS
    if bad(Meta.parseall(read(f, String); filename = f))
        println("PARSE ERROR ", f); global n += 1
    end
end
println(length(ARGS) - n, " of ", length(ARGS), " parse")
exit(n == 0 ? 0 : 1)
