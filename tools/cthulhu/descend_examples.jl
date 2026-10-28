# W-85: Cthulhu's descent over the code compiled by facts (TraitWorld's extension TraitWorldCthulhuExt), driven
# non-interactively: Cthulhu's own entry points (a body's callsites as its menu lists them), then sessions in
# Cthulhu's virtual terminal (Cthulhu.Testing): the first screen, one descent, quit.
#     julia --project=experiments/tools/cthulhu experiments/tools/cthulhu/descend_examples.jl
using Cthulhu, TraitWorld
using Cthulhu.Testing
const CH = Cthulhu
include(joinpath(@__DIR__, "..", "..", "w80", "x6.jl"))          # E-218's integrators, `run_cb`
using DataFrames
using DataFrames: innerrows, tocolumn

"The callsites Cthulhu lists for `f(::types...)` with the facts provider (its menu's lines)."
function menu(f, types; optimize = true)
    p = TraitWorld.facts_provider()
    mi = CH.find_method_instance(p, f, types)
    ci = CH.generate_code_instance(p, mi)
    r = CH.lookup(p, ci, optimize)
    cs, _ = CH.find_callsites(p, r, ci)
    println("== callsites of ", mi, " (code instance of the owner ", repr(ci.owner), ")")
    for c in cs
        println("  ", sprint(show, c))
    end
    println()
    return cs
end
menu(c::TraitWorld.CallPath) = menu(c.worker_sig.parameters[1].instance, Tuple{c.worker_sig.parameters[2:end]...})

"A session in Cthulhu's virtual terminal: the first screen's menu, the descent into callsite `k`, quit."
function session(f, args...; k::Int = 1, show_code = false)
    CH.CONFIG = CH.CthulhuConfig(; menu_options = (; pagesize = 10000))
    term = VirtualTerminal(; context = [:color => false, :displaysize => (200, 200)])
    h = @run term TraitWorld.descend_facts(f, args...; view = :typed, optimize = true, iswarn = false, terminal = term)
    _, text = read_next(h)
    println("== descend_facts: the first screen", show_code ? "" : " (its menu)")
    println(show_code ? text : text[something(findfirst("Select a call", text), 1:1).start:end])
    for _ in 1:(k - 1)
        write(term, :down)
        skip_delimiter(h)                  # the menu drawn again
    end
    write(term, :enter)
    _, text = read_next(h)
    println("== after descending into callsite ", k)
    println(text)
    println("session ended: ", end_terminal_session(h))
    println()
end

# E-218: the loop in trait code; the worker of the method chosen for an IntB
menu(X6.run_cb, (Vector{Dynamic{IntegratorView}}, Int))
menu(TraitWorld.callpath(cb, is[2]; time = false))
session(X6.run_cb, (Vector{Dynamic{IntegratorView}}, Int); k = 4)                 # into `fallback`

# the forks' join kernel on two integer columns
l = tocolumn([1, 2, 3, 5, 8, 13]); r = tocolumn([2, 3, 5, 7, 11, 13, 17])
cp = TraitWorld.callpath(innerrows, l, r, true, false)
display(cp); println()
menu(cp)
session(cp; k = 3)                                                              # into `_issorted`
