# W-85: checks of TraitWorld's Cthulhu extension, non-interactive (the facts provider's callsites, a session).
#     julia --project=experiments/tools/cthulhu experiments/tools/cthulhu/test_descend.jl
using Test, Cthulhu, TraitWorld
using Cthulhu.Testing
const CH = Cthulhu
include(joinpath(@__DIR__, "..", "..", "w80", "x6.jl"))
using DataFrames: innerrows, tocolumn

function callsites(f, types)
    p = TraitWorld.facts_provider()
    ci = CH.generate_code_instance(p, CH.find_method_instance(p, f, types))
    cs, _ = CH.find_callsites(p, CH.lookup(p, ci, true), ci)
    return ci, String[sprint(show, c) for c in cs]
end

@testset "TraitWorldCthulhuExt" begin
    @test Base.get_extension(TraitWorld, :TraitWorldCthulhuExt) isa Module
    ci, cs = callsites(X6.run_cb, (Vector{Dynamic{IntegratorView}}, Int))
    @test ci.owner === :facts
    @test any(s -> occursin("[dispatch] _enter_erased", s), cs)
    @test any(s -> occursin("[dispatch] +(::Any,::Any)", s), cs)
    @test any(s -> occursin("rare: error", s), cs)
    @test any(s -> occursin("invoke fallback", s), cs)                 # an invoke stays descendable
    # the same sites as factscode, as the menu's runtime calls
    fc = TraitWorld.factscode(X6.run_cb, (Vector{Dynamic{IntegratorView}}, Int); depth = 0)
    @test all(s -> any(c -> startswith(c, "%$(s.stmt) = runtime"), cs), fc.sites)
    c = TraitWorld.callpath(cb, is[2]; time = false)
    _, ws = callsites(c.worker_sig.parameters[1].instance, Tuple{c.worker_sig.parameters[2:end]...})
    @test count(s -> occursin("[split table]", s), ws) == 3
    # plain inference: no facts owner
    p = TraitWorld.facts_provider(; facts = false)
    @test CH.generate_code_instance(p, CH.find_method_instance(p, +, (Int, Int))).owner === nothing
    # a session in the virtual terminal: the kernel's worker, then `_issorted`
    CH.CONFIG = CH.CthulhuConfig(; menu_options = (; pagesize = 10000))
    cp = TraitWorld.callpath(innerrows, tocolumn([1, 2, 3]), tocolumn([2, 3, 4]), true, false; time = false)
    term = VirtualTerminal(; context = [:color => false, :displaysize => (200, 200)])
    h = @run term TraitWorld.descend_facts(cp; view = :typed, optimize = true, iswarn = false, terminal = term)
    _, text = read_next(h)
    @test occursin("[split table] nrows on a Dynamic{Column{Int64}}", text)
    write(term, :down); skip_delimiter(h); write(term, :down); skip_delimiter(h); write(term, :enter)
    _, text = read_next(h)
    @test occursin("_issorted(c::TObj", text)
    @test occursin("[split table] cell on a Dynamic{Column{Int64}}", text)
    @test end_terminal_session(h)
end
