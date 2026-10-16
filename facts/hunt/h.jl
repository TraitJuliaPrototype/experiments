# harness
using TraitWorld
const RESULTS = Any[]
res(th) = try Base.invokelatest(th) catch e; (:error, typeof(e), first(sprint(showerror, e), 80)) end
P(f, args...) = res(() -> TraitWorld._facts_call(f, args...))
macro wrap(name, f)
    esc(:($name(args...) = TraitWorld._facts_call($f, args...)))
end
function check(name, plain, pol...)
    ok = all(p -> isequal(p, plain) || (p isa Tuple && plain isa Tuple && length(p) >= 2 && p[1:2] == plain[1:2]), pol)
    push!(RESULTS, (name, ok))
    println(ok ? "PASS  " : "FAIL  ", name, "   plain=", repr(plain), "  policy=", join(map(repr, pol), " | "))
    flush(stdout)
end
summary() = (println("\n", count(last, RESULTS), "/", length(RESULTS), " pass"); for (n, o) in RESULTS; o || println("  FAIL: ", n); end)
