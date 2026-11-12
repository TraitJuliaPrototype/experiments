# W-143 (open issue 179): how much of Base's and the standard libraries' surface is fully typed at the
# signatures typed code calls it with. For each exported function, the signatures over a few broad
# types at which it has a method and a result; `fully_typed` at each; the holes grouped by their cause.
# The report is the session's (traits T-107): it can take a call as resolved that a build does not.
# Run from TraitWorld-unified:
#   julia --startup-file=no --project=. ../experiments/unification/w143/base_surface.jl [seconds] [modules…]
using TraitWorld
const BUDGET = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 420.0
const MODS = length(ARGS) >= 2 ? [Core.eval(Main, :(import $(Symbol(a)); $(Symbol(a)))) for a in ARGS[2:end]] : Module[Base]
const TS = Any[String, Int, Float64, Bool, Char, Symbol, Vector{Int}, Vector{Float64}, Vector{String},
               Dict{String,Int}, Tuple{Int,Int}, UnitRange{Int}]
sigs = Any[(T,) for T in TS]
for T in TS
    push!(sigs, (T, T))
    T === Int || push!(sigs, (T, Int))
    T === String || push!(sigs, (T, String))
end
function callable_at(f, ts)
    hasmethod(f, Tuple{ts...}) || return false
    rt = try Base.infer_return_type(f, Tuple{ts...}) catch; Union{} end
    return rt !== Union{}
end
t0 = time()
tried = 0; typed = 0; failed = 0; skipped = 0; holesigs = 0; onlyunknown = 0; nsites = 0
byfun = Dict{String,Int}(); bycause = Dict{String,Int}(); bycallee = Dict{String,Int}()
examples = Dict{String,String}()
names_done = 0; names_all = 0
norm(c) = replace(c, r"\d+" => "N")
for M in MODS
    for n in sort!(collect(names(M)))
        global names_all += 1
        isdefined(M, n) || continue
        f = getfield(M, n)
        (f isa Function && !startswith(string(n), "@")) || continue
        if time() - t0 > BUDGET
            global skipped += 1
            continue
        end
        global names_done += 1
        for ts in sigs
            callable_at(f, ts) || continue
            global tried += 1
            r = try fully_typed(f, ts) catch; nothing end
            if r === nothing
                global failed += 1
            elseif isfullytyped(r)
                global typed += 1
            else
                key = string(M, ".", n)
                byfun[key] = get(byfun, key, 0) + 1
                global holesigs += 1
                seen = Set{String}()
                for s in r.sites
                    c = isempty(s.cause) ? "(no cause)" : norm(last(s.cause))
                    c in seen && continue
                    push!(seen, c)
                    bycause[c] = get(bycause, c, 0) + 1
                    get!(examples, c, string(n, ts, ": ", s.call, " at ", s.file, ":", s.line))
                end
                seen == Set(["its argument types are not known when compiled"]) && (global onlyunknown += 1)
                for s in r.sites
                    global nsites += 1
                    d = s.code.def
                    k = d isa Method ? string(d.module, ".", d.name) : string(d)
                    bycallee[k] = get(bycallee, k, 0) + 1
                end
            end
        end
    end
end
println("modules ", MODS, "; exported functions looked at ", names_done, " (", skipped, " left when the budget of ", BUDGET, " s ran out)")
println("signatures with a method and a result: ", tried, "; fully typed ", typed, " (", round(100 * typed / max(tried, 1); digits = 1),
        " %); with a hole ", tried - typed - failed, "; the report failed ", failed)
println("\nfunctions with a hole at some signature: ", length(byfun))
top(d, k) = first(sort!(collect(d); by = last, rev = true), k)
println("\nthe holes by root cause (signatures it appears in):")
for (c, k) in top(bycause, 25)
    println(lpad(k, 6), "  ", first(c, 110), "\n          e.g. ", first(examples[c], 150))
end
println("\nsignatures whose only cause is a call whose argument types are not known (a union the session does not split): ", onlyunknown, " of ", holesigs)
srt = sort!(collect(values(bycallee)); rev = true)
println("\nthe functions the holes sit in: ", length(bycallee), " functions, ", nsites, " sites; the first 5 hold ",
        round(100 * sum(first(srt, 5)) / max(nsites, 1); digits = 0), " %, the first 20 ", round(100 * sum(first(srt, 20)) / max(nsites, 1); digits = 0), " %")
for (c, k) in top(bycallee, 25)
    println(lpad(k, 6), "  ", c)
end
println("\nexported functions with the most signatures with a hole:")
for (c, k) in top(byfun, 25)
    println(lpad(k, 6), "  ", c)
end
println("\nelapsed ", round(time() - t0; digits = 0), " s")
